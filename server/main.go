package main

import (
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
	middleware "github.com/go-chi/chi/v5/middleware"
)

func isFile(filepath string) bool {

	fileInfo, err := os.Stat(filepath)
	if err != nil {
		return false
	}

	return !fileInfo.IsDir()
}

func corsControlMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if len(origin) != 0 {
			w.Header().Set("access-control-allow-origin", origin)
			w.Header().Set("access-control-allow-credentials", "true")
			w.Header().Set("access-control-allow-methods", "GET,POST,DELETE,OPTIONS")
		}
		if r.Method == "OPTIONS" {
			return
		}

		next.ServeHTTP(w, r)
	})
}

func main() {
	log.Printf("powerboards UI starting")

	root := os.Getenv("ROOT")
	if root == "" {
		root = "/app"
	}

	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Compress(5))
	r.Use(corsControlMiddleware)

	r.Get("/.well-known/apple-app-site-association", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		http.ServeFile(w, r, filepath.Join(root, ".well-known/apple-app-site-association"))
	})

	r.Get("/.well-known/assetlinks.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		http.ServeFile(w, r, filepath.Join(root, ".well-known/assetlinks.json"))
	})

	r.Get("/*", func(w http.ResponseWriter, r *http.Request) {
		stripPort := func(h string) string {
			if i := strings.IndexByte(h, ':'); i >= 0 {
				return h[:i]
			}
			return h
		}
		isIP := func(h string) bool {
			return net.ParseIP(h) != nil
		}
		hasSubdomain := func(h string) bool {
			// Very simple heuristic: apex like example.com has 1 dot.
			// subdomains like app.example.com have >= 2 dots.
			return strings.Count(h, ".") >= 2
		}
		redirectToHost := func(newHost string) {
			pathAndQuery := r.URL.Path
			if len(r.URL.RawQuery) > 0 {
				pathAndQuery += "?" + r.URL.RawQuery
			}
			http.Redirect(w, r, "https://"+newHost+pathAndQuery, http.StatusFound)
		}

		filePath := filepath.Join(root, r.URL.Path)
		if strings.Contains(filePath, "main.dart.js") {
			filePath = filepath.Join(root, "main.dart.js")
		}

		// Collect candidate hosts from proxy headers and request.
		hosts := []string{
			r.Header.Get("X-Forwarded-Host"),
			r.Header.Get("X-Origin-Host"),
			r.Host,
		}

		// Normalize possible multi-valued X-Forwarded-Host (comma-separated)
		var canonHosts []string
		for _, h := range hosts {
			for _, part := range strings.Split(h, ",") {
				part = strings.TrimSpace(part)
				if part != "" {
					canonHosts = append(canonHosts, part)
				}
			}
		}

		// Redirect logic
		for _, raw := range canonHosts {
			h := stripPort(raw)
			if h == "" || strings.EqualFold(h, "localhost") || isIP(h) {
				continue
			}

			// Already on app.* -> no redirect
			if strings.HasPrefix(h, "app.") {
				break
			}

			// www.* -> app.*
			if strings.HasPrefix(h, "www.") {
				newHost := "app." + strings.TrimPrefix(h, "www.")
				redirectToHost(newHost)
				return
			}

			// Apex/bare domain (e.g., powerboards.life) -> app.powerboards.life
			// Heuristic: exactly one dot and not a public-suffix edge case.
			if !hasSubdomain(h) {
				newHost := "app." + h
				redirectToHost(newHost)
				return
			}
		}

		for _, host := range canonHosts {
			domainPath := filepath.Join(root, stripPort(host), r.URL.Path)
			if isFile(domainPath) {
				http.ServeFile(w, r, domainPath)
				return
			}
		}

		if isFile(filePath) {
			http.ServeFile(w, r, filePath)
		} else {
			http.ServeFile(w, r, fmt.Sprintf("%s/index.html", root))
		}
	})

	// Start the server
	http.ListenAndServe(":80", r)
}
