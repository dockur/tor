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

// Configuration loaded from environment variables. Contains defaults if none are set.
var (
	controlAddr     = getEnv("TOR_CONTROL_ADDR", "127.0.0.1:9051")
	controlPassword = getEnv("TOR_CONTROL_PASSWORD", "password")
	debugMode       = getEnv("DEBUG", "false") == "true"
)

const (
	onionooAPIURL = "https://onionoo.torproject.org/details?lookup=%s"
	timeout       = 10 * time.Second
)

// getEnv reads an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
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

func healthcheck() error {
	// Connect to Tor Control Port
	conn, err := net.DialTimeout("tcp", controlAddr, timeout)
	if err != nil {
		return fmt.Errorf("failed to connect to control port: %w", err)
	}
	defer conn.Close()

	// Set a deadline for the connection
	err = conn.SetDeadline(time.Now().Add(timeout))
	if err != nil {
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

	// Query Onionoo API
	if err := checkOnionoo(fingerprint); err != nil {
		return fmt.Errorf("onionoo check failed: %w", err)
	}

	return nil
}

func authenticate(conn net.Conn, reader *bufio.Reader) error {
	// Send AUTHENTICATE command with the plaintext password
	// Tor performs S2K hashing internally and validates against HashedControlPassword which is set in torrc
	// To set HashedControlPassword, run `tor --hash-password <password>` and put the result in torrc
	cmd := fmt.Sprintf("AUTHENTICATE \"%s\"\r\n", controlPassword)

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
		if debugMode {
			fmt.Fprintf(os.Stderr, "DEBUG: Tor response: %q\n", line)
		}

		// Looks for the Fingerprint line
		if strings.HasPrefix(line, "250-fingerprint=") {
			fingerprint = strings.TrimPrefix(line, "250-fingerprint=")
			// Removes spaces to be compatible with Onionoo API
			fingerprint = strings.ReplaceAll(fingerprint, " ", "")
			// Convert to uppercase for Onionoo API
			fingerprint = strings.ToUpper(fingerprint)
		} else if strings.HasPrefix(line, "250 ") {
			// End of response
			break
		} else if strings.HasPrefix(line, "551") {
			// Not running as relay
			return "", fmt.Errorf("not running as a relay: %s", line)
		}
	}

	if fingerprint == "" {
		return "", fmt.Errorf("fingerprint not found in response")
	}

	// Validation: must be 40 characters long
	if len(fingerprint) != 40 {
		return "", fmt.Errorf("invalid fingerprint length: got %d chars, expected 40", len(fingerprint))
	}

	// Validation: must only contain hex characters
	for _, char := range fingerprint {
		if !((char >= '0' && char <= '9') || (char >= 'A' && char <= 'F')) {
			return "", fmt.Errorf("invalid fingerprint: contains non-hex character '%char'", char)
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

	// Checks if the relay is, consensus-wise, running
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
