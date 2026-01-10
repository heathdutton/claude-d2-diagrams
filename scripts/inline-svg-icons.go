// inline-svg-icons.go - Convert <image> tags to inline <svg> for GitHub compatibility
//
// GitHub's SVG sanitizer strips <image> tags. This script:
// 1. Finds <image href="data:image/svg+xml;base64,..."> tags
// 2. Decodes the base64 SVG content
// 3. Replaces with inline <svg> elements that GitHub allows
//
// Build: go build -o inline-svg-icons inline-svg-icons.go
// Usage: ./inline-svg-icons <svg-file>
//        ./inline-svg-icons --all <directory>

package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var (
	// Match <image> tags with base64 SVG data
	imageTagRegex = regexp.MustCompile(`<image\s+[^>]*href="data:image/svg\+xml;base64,([^"]+)"[^>]*>`)
	// Extract attributes
	xAttrRegex      = regexp.MustCompile(`\sx="([^"]+)"`)
	yAttrRegex      = regexp.MustCompile(`\sy="([^"]+)"`)
	widthAttrRegex  = regexp.MustCompile(`\swidth="([^"]+)"`)
	heightAttrRegex = regexp.MustCompile(`\sheight="([^"]+)"`)
	// Extract viewBox from inner SVG
	viewBoxRegex = regexp.MustCompile(`viewBox="([^"]+)"`)
	// Extract content between <svg> and </svg>
	svgContentRegex = regexp.MustCompile(`(?s)<svg[^>]*>(.*)</svg>`)
	// For making IDs unique
	idAttrRegex    = regexp.MustCompile(`id="([^"]+)"`)
	urlRefRegex    = regexp.MustCompile(`url\(#([^)]+)\)`)
	xlinkHrefRegex = regexp.MustCompile(`xlink:href="#([^"]+)"`)
	hrefHashRegex  = regexp.MustCompile(`href="#([^"]+)"`)
)

func inlineIconsInFile(filePath string) error {
	// Read file
	content, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	svg := string(content)
	counter := 0

	// Find and replace all <image> tags with base64 SVG
	result := imageTagRegex.ReplaceAllStringFunc(svg, func(match string) string {
		counter++

		// Extract base64 data
		base64Match := imageTagRegex.FindStringSubmatch(match)
		if len(base64Match) < 2 {
			fmt.Printf("Warning: Could not extract base64 data from icon %d\n", counter)
			return match
		}
		base64Data := base64Match[1]

		// Extract position and size attributes
		x := extractAttr(xAttrRegex, match, "0")
		y := extractAttr(yAttrRegex, match, "0")
		width := extractAttr(widthAttrRegex, match, "64")
		height := extractAttr(heightAttrRegex, match, "64")

		// Decode base64
		decoded, err := base64.StdEncoding.DecodeString(base64Data)
		if err != nil {
			fmt.Printf("Warning: Failed to decode base64 for icon %d: %v\n", counter, err)
			return match
		}
		decodedStr := string(decoded)

		// Extract viewBox
		viewBox := "0 0 " + width + " " + height
		if vbMatch := viewBoxRegex.FindStringSubmatch(decodedStr); len(vbMatch) > 1 {
			viewBox = vbMatch[1]
		}

		// Extract inner content
		inner := decodedStr
		// Remove XML declaration
		if idx := strings.Index(inner, "?>"); idx != -1 {
			inner = inner[idx+2:]
		}
		// Extract content between <svg> and </svg>
		if contentMatch := svgContentRegex.FindStringSubmatch(inner); len(contentMatch) > 1 {
			inner = contentMatch[1]
		}

		// Make IDs unique
		prefix := fmt.Sprintf("icon%d_", counter)
		inner = idAttrRegex.ReplaceAllString(inner, `id="`+prefix+`$1"`)
		inner = urlRefRegex.ReplaceAllString(inner, `url(#`+prefix+`$1)`)
		inner = xlinkHrefRegex.ReplaceAllString(inner, `xlink:href="#`+prefix+`$1"`)
		// Be careful not to replace href="http..." or href="data:..."
		inner = hrefHashRegex.ReplaceAllStringFunc(inner, func(m string) string {
			if strings.Contains(m, "xlink:") {
				return m // Already handled
			}
			return hrefHashRegex.ReplaceAllString(m, `href="#`+prefix+`$1"`)
		})

		// Build replacement
		replacement := fmt.Sprintf(
			`<svg x="%s" y="%s" width="%s" height="%s" viewBox="%s" xmlns="http://www.w3.org/2000/svg">%s</svg>`,
			x, y, width, height, viewBox, inner,
		)

		return replacement
	})

	if counter == 0 {
		fmt.Printf("No base64 SVG images found in %s\n", filePath)
		return nil
	}

	// Write result
	if err := os.WriteFile(filePath, []byte(result), 0644); err != nil {
		return fmt.Errorf("failed to write file: %w", err)
	}

	fmt.Printf("Inlined %d icons in %s\n", counter, filePath)
	return nil
}

func extractAttr(regex *regexp.Regexp, s, defaultVal string) string {
	if match := regex.FindStringSubmatch(s); len(match) > 1 {
		return match[1]
	}
	return defaultVal
}

func processDirectory(dir string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return fmt.Errorf("failed to read directory: %w", err)
	}

	count := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if strings.HasSuffix(entry.Name(), ".svg") {
			filePath := filepath.Join(dir, entry.Name())
			fmt.Printf("Processing: %s\n", filePath)
			if err := inlineIconsInFile(filePath); err != nil {
				fmt.Printf("Error processing %s: %v\n", filePath, err)
			}
			count++
		}
	}

	fmt.Printf("Processed %d SVG files\n", count)
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: inline-svg-icons <svg-file>")
		fmt.Println("       inline-svg-icons --all <directory>")
		os.Exit(1)
	}

	if os.Args[1] == "--all" {
		if len(os.Args) < 3 {
			fmt.Println("Usage: inline-svg-icons --all <directory>")
			os.Exit(1)
		}
		if err := processDirectory(os.Args[2]); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	} else {
		if err := inlineIconsInFile(os.Args[1]); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
	}
}
