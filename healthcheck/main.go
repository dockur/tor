package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	healthcheckEnvFile = "/run/tor/healthcheck.env"
	onionooAPIURL      = "https://onionoo.torproject.org/details?lookup=%s"
	timeout            = 10 * time.Second
)

// Configuration loaded from /run/tor/healthcheck.env and environment variables.
// Contains defaults if none are set.
var (
	config = loadConfig()
)

type Config struct {
	ControlAddr     string
	ControlPassword string
	DebugMode       bool
	ExternalCheck   bool
}

type OnionooResponse struct {
	Version         string `json:"version"`
	RelaysPublished string `json:"relays_published"`
	Relays          []struct {
		Nickname    string   `json:"nickname"`
		Fingerprint string   `json:"fingerprint"`
		Running     bool     `json:"running"`
		Flags       []string `json:"flags"`
	} `json:"relays"`
	Bridges []interface{} `json:"bridges"`
}

func main() {
	if err := healthcheck(); err != nil {
		fmt.Fprintf(os.Stderr, "Healthcheck failed: %v\n", err)
		os.Exit(1)
	}

	os.Exit(0)
}

// loadConfig starts with environment/default values, then lets
// healthcheck.env override them with the values resolved by the entrypoint.
func loadConfig() Config {
	values := map[string]string{
		"ADDR":     "127.0.0.1:9051",
		"PASSWORD": "password",
		"DEBUG":    "false",
		"CHECK":    "false",
	}

	for key := range values {
		if value := os.Getenv(key); value != "" {
			values[key] = value
		}
	}

	if fileValues, err := readEnvFile(healthcheckEnvFile); err == nil {
		for key, value := range fileValues {
			if value != "" {
				values[key] = value
			}
		}
	} else if isEnabled(values["DEBUG"]) {
		fmt.Fprintf(os.Stderr, "DEBUG: failed to read %s: %v\n", healthcheckEnvFile, err)
	}

	return Config{
		ControlAddr:     values["ADDR"],
		ControlPassword: values["PASSWORD"],
		DebugMode:       isEnabled(values["DEBUG"]),
		ExternalCheck:   isEnabled(values["CHECK"]),
	}
}

// readEnvFile reads a simple KEY=value environment file.
func readEnvFile(path string) (map[string]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	values := make(map[string]string)
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()

		if strings.TrimSpace(line) == "" || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}

		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}

		key = strings.TrimSpace(key)

		if key != "" {
			values[key] = value
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return values, nil
}

// isEnabled returns true for the same values accepted by healthcheck.sh.
func isEnabled(value string) bool {
	value = strings.TrimSpace(value)

	return strings.EqualFold(value, "true") ||
		strings.HasPrefix(value, "Y") ||
		strings.HasPrefix(value, "y") ||
		strings.HasPrefix(value, "1")
}

func healthcheck() error {
	if config.ControlAddr == "" {
		return fmt.Errorf("control address is empty")
	}

	// Connect to Tor Control Port
	conn, err := net.DialTimeout("tcp", config.ControlAddr, timeout)
	if err != nil {
		return fmt.Errorf("failed to connect to control port: %w", err)
	}
	defer conn.Close()

	// Set a deadline for the connection
	if err := conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		return err
	}

	reader := bufio.NewReader(conn)

	// Authenticate with Tor Control Port
	if err := authenticate(conn, reader); err != nil {
		return fmt.Errorf("authentication failed: %w", err)
	}

	// Get fingerprint from Control Port
	fingerprint, err := getFingerprint(conn, reader)
	if err != nil {
		return fmt.Errorf("failed to get fingerprint: %w", err)
	}

	// Query Onionoo API when relay mode is active and external checks are enabled
	if config.ExternalCheck && !strings.HasPrefix(fingerprint, "skip") {
		if err := checkOnionoo(fingerprint); err != nil {
			return fmt.Errorf("onionoo check failed: %w", err)
		}
	}

	return nil
}

func authenticate(conn net.Conn, reader *bufio.Reader) error {
	// Send AUTHENTICATE command with the plaintext password.
	// Tor performs S2K hashing internally and validates against HashedControlPassword,
	// which is set in torrc. To set HashedControlPassword manually, run:
	// `tor --hash-password <password>` and put the result in torrc.
	cmd := fmt.Sprintf("AUTHENTICATE \"%s\"\r\n", escapeControlString(config.ControlPassword))

	if _, err := conn.Write([]byte(cmd)); err != nil {
		return err
	}

	response, err := reader.ReadString('\n')
	if err != nil {
		return err
	}

	if !strings.HasPrefix(response, "250") {
		return fmt.Errorf("authentication failed: %s", strings.TrimSpace(response))
	}

	return nil
}

// escapeControlString escapes backslashes and quotes for Tor's quoted
// control-protocol string syntax.
func escapeControlString(value string) string {
	value = strings.ReplaceAll(value, "\\", "\\\\")
	value = strings.ReplaceAll(value, "\"", "\\\"")
	return value
}

func getFingerprint(conn net.Conn, reader *bufio.Reader) (string, error) {
	if _, err := conn.Write([]byte("GETINFO fingerprint\r\n")); err != nil {
		return "", err
	}

	// Parse response
	var fingerprint string

	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			return "", err
		}

		line = strings.TrimSpace(line)

		// Debug: Show raw response from Tor Control Protocol
		if config.DebugMode {
			fmt.Fprintf(os.Stderr, "DEBUG: Tor response: %q\n", line)
		}

		// Look for the Fingerprint line
		switch {
		case strings.HasPrefix(line, "250-fingerprint="):
			fingerprint = strings.TrimPrefix(line, "250-fingerprint=")
			// Remove spaces to be compatible with Onionoo API
			fingerprint = strings.ReplaceAll(fingerprint, " ", "")
			// Convert to uppercase for Onionoo API
			fingerprint = strings.ToUpper(fingerprint)

		case strings.HasPrefix(line, "250 "):
			// No fingerprint usually means Tor is running as a client, not a relay
			if fingerprint == "" {
				return "skip", nil
			}

			return validateFingerprint(fingerprint)

		case strings.HasPrefix(line, "551"):
			// Not running as relay
			return "skip", nil
		}
	}
}

func validateFingerprint(fingerprint string) (string, error) {
	// Validation: must be 40 characters long
	if len(fingerprint) != 40 {
		return "", fmt.Errorf("invalid fingerprint length: got %d chars, expected 40", len(fingerprint))
	}

	// Validation: must only contain hex characters
	for _, char := range fingerprint {
		if !((char >= '0' && char <= '9') || (char >= 'A' && char <= 'F')) {
			return "", fmt.Errorf("invalid fingerprint: contains non-hex character %q", char)
		}
	}

	return fingerprint, nil
}

func checkOnionoo(fingerprint string) error {
	client := &http.Client{
		Timeout: timeout,
	}

	url := fmt.Sprintf(onionooAPIURL, fingerprint)
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to query onionoo API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("onionoo API returned status %d", resp.StatusCode)
	}

	var buf bytes.Buffer
	if _, err := buf.ReadFrom(resp.Body); err != nil {
		return fmt.Errorf("failed to read response body: %w", err)
	}

	var onionoo OnionooResponse
	if err := json.Unmarshal(buf.Bytes(), &onionoo); err != nil {
		return fmt.Errorf("failed to parse onionoo response: %w", err)
	}

	// Check if the relay is, consensus-wise, running
	if len(onionoo.Relays) == 0 {
		return fmt.Errorf("relay %s not found in onionoo database (new relays may take hours to appear)", fingerprint)
	}

	relay := onionoo.Relays[0]

	// Print relay details
	fmt.Fprintf(os.Stderr, "Found relay: %s (fingerprint: %s)\n", relay.Nickname, relay.Fingerprint)

	// Return error if fingerprints don't match
	if !strings.EqualFold(relay.Fingerprint, fingerprint) {
		return fmt.Errorf("fingerprint mismatch: requested %s, got %s", fingerprint, relay.Fingerprint)
	}

	// Return error if relay is not running
	if !relay.Running {
		return fmt.Errorf("relay %s is not running according to onionoo", relay.Nickname)
	}

	// Return error if relay has no flags
	if len(relay.Flags) == 0 {
		return fmt.Errorf("relay %s has no flags (not yet in consensus or not listed)", relay.Nickname)
	}

	// Log successful validation
	fmt.Fprintf(os.Stderr, "Relay is running with flags: %v\n", relay.Flags)

	return nil
}
