---
paths:
  - "**/*.java"
  - "**/pom.xml"
  - "**/build.gradle"
  - "**/build.gradle.kts"
---
# Java Hooks

## PostToolUse Hooks

Configure in `~/.claude/settings.json`:

- **google-java-format**: Auto-format `.java` files after edit
- **checkstyle**: Run style checks after editing Java files
- **./mvnw compile** or **./gradlew compileJava**: Verify compilation after changes
