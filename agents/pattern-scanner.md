# Pattern Scanner Agent

> **Role**: Scan the step-definitions repo and build a complete index of all
> registered Cucumber patterns, their owning classes, and parameter signatures.

## Trigger

Spawned by the main `write-step-def` orchestrator when it needs to know what
patterns already exist — especially in `gap-analysis` and `from-feature` modes.

## Inputs

You will receive:
- `repo_path`: Root of the step-definitions repo (e.g., `./raf-automation`)
- `domain_filter`: Optional domain to narrow the scan (e.g., `ui`, `risk`)
- `keyword_filter`: Optional keywords to prioritize (e.g., `["notification", "click", "validate"]`)

## Execution Steps

### 1. Locate Step Definition Classes

```bash
# If domain_filter is provided, scope to that package
find {repo_path}/src/main/java/com/theocc/raf/automation/stepdefs/{domain_filter} \
  -name "*.java" -type f

# If no domain_filter, scan all
find {repo_path}/src/main/java/com/theocc/raf/automation/stepdefs/ \
  -name "*.java" -type f
```

### 2. Extract Annotations

For each `.java` file, extract lines matching `@Given`, `@When`, `@Then`, `@And`, `@But`:

```bash
grep -n '@\(Given\|When\|Then\|And\|But\)(' {file} | head -200
```

### 3. Parse Into Structured Index

For each annotation, extract:
- **Pattern**: The string inside the annotation (regex or Cucumber Expression)
- **Type**: Given / When / Then / And / But
- **Method name**: The Java method name on the following line
- **Parameters**: Types and names from the method signature
- **Class**: Fully qualified class name
- **File**: Relative path from repo root
- **Line**: Line number of the annotation

### 4. Build the Index

Output a JSON structure:

```json
{
  "scan_metadata": {
    "repo_path": "...",
    "domain_filter": "...",
    "total_classes": 45,
    "total_patterns": 312,
    "scan_timestamp": "..."
  },
  "patterns": [
    {
      "type": "Given",
      "pattern": "rest client is created with properties file {string}",
      "pattern_type": "cucumber_expression",
      "method": "createRestClient",
      "params": [{"type": "String", "name": "propertiesFile"}],
      "class": "com.theocc.raf.automation.stepdefs.common.RestClientSteps",
      "file": "src/main/java/.../RestClientSteps.java",
      "line": 28
    }
  ]
}
```

### 5. Keyword Relevance Scoring

If `keyword_filter` is provided, score each pattern by keyword overlap:
- Exact keyword match in pattern text → score +3
- Partial keyword match → score +1
- Same domain package → score +1

Sort output by relevance score (descending), then alphabetically.

### 6. Collision Detection

Flag any patterns that are ambiguous or overlapping:
- Two patterns that would match the same Gherkin line
- Patterns that differ only in parameter names but not structure

```json
{
  "collisions": [
    {
      "pattern_a": "user clicks on element {string}",
      "class_a": "UIActionSteps",
      "pattern_b": "user clicks on element {string} in section {string}",
      "class_b": "SectionActionSteps",
      "risk": "LOW — different arity, Cucumber can disambiguate"
    }
  ]
}
```

## Output

Return the full index to the main orchestrator. The orchestrator uses it to:
1. Skip generating code for patterns that already exist
2. Identify the correct class to extend (add-steps mode)
3. Build the gap report (gap-analysis mode)
4. Detect naming conflicts before generating new patterns

## Performance Notes

- For a repo with ~300 step classes, this scan takes ~10-15 seconds
- Cache the index in memory for the duration of the session
- Re-scan only if the user indicates the repo has changed
