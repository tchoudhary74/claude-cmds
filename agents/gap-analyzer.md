# Gap Analyzer Agent

> **Role**: Cross-reference all Gherkin steps in feature files against the
> step-definitions pattern index. Report which steps are undefined (gaps)
> and recommend which classes should own the new definitions.

## Trigger

Spawned by the main `write-step-def` orchestrator in `gap-analysis` or
`from-feature` modes. Requires the pattern index from Pattern Scanner.

## Inputs

- `pattern_index`: The JSON index produced by Pattern Scanner agent
- `feature_paths`: Either a single .feature file or a glob of feature files
- `module`: The module context (risk/clearing/sdp/ui)

## Execution Steps

### 1. Extract All Gherkin Steps from Features

```bash
# Single feature
grep -n '^\s*\(Given\|When\|Then\|And\|But\)\b' {feature_path}

# Multiple features (gap-analysis mode)
find {module}-features/src/test/resources/features/ -name "*.feature" \
  -exec grep -Hn '^\s*\(Given\|When\|Then\|And\|But\)\b' {} \;
```

**Normalize each step:**
1. Strip leading whitespace
2. Strip the keyword (Given/When/Then/And/But)
3. Replace quoted strings with `{string}` placeholder
4. Replace integers with `{int}` placeholder
5. Replace table rows (lines starting with `|`) — these are DataTable params

### 2. Match Steps Against Pattern Index

For each normalized step:
1. Try exact match against all patterns in the index
2. Try regex match (for regex-style patterns)
3. Try Cucumber Expression match (for expression-style patterns)
4. Score confidence: EXACT (100%), LIKELY (80%+), PARTIAL (50%+), NONE (gap)

### 3. Classify Results

```
MATCHED   — Step has a corresponding pattern in the index (confidence ≥ 80%)
PROBABLE  — Step likely matches but pattern has subtle differences (50-79%)
GAP       — No matching pattern found (confidence < 50%)
AMBIGUOUS — Step matches multiple patterns (needs human decision)
```

### 4. Group Gaps by Domain

For each GAP step, determine which domain it belongs to based on:
- The feature file's directory path
- The step's action type (UI action → ui, API call → the relevant backend domain)
- Keywords in the step text

### 5. Recommend Class Assignment

For each GAP step, recommend which existing class should own it (extend)
or whether a new class is needed:

**Decision logic:**
```
IF a class in the same domain has ≥3 methods with similar keywords:
  → Recommend adding to that existing class

ELSE IF the gap is a common utility (logging, state management):
  → Recommend adding to CommonSteps or UtilitySteps

ELSE:
  → Recommend creating a new class
  → Suggest name: {Domain}{Action}Steps.java
```

### 6. Produce Gap Report

**For from-feature mode (single file):**

```markdown
## Step Definition Gap Report
**Feature**: {feature_path}
**Scanned**: {timestamp}

### Summary
| Status    | Count |
|-----------|-------|
| Matched   | 38    |
| Probable  | 2     |
| Gap       | 5     |
| Ambiguous | 0     |

### Gaps — New Step Definitions Needed

| # | Gherkin Step | Recommended Class | Action |
|---|-------------|-------------------|--------|
| 1 | user filters notifications by date range {string} to {string} | NotificationFilterSteps.java (NEW) | Create method |
| 2 | validate notification count is {int} | NotificationValidationSteps.java (EXTEND) | Add to existing |

### Probable Matches — Verify These

| # | Gherkin Step | Closest Pattern | Class | Confidence |
|---|-------------|----------------|-------|------------|
| 1 | user clicks filter button | user clicks on element {string} | UIActionSteps | 75% |
```

**For gap-analysis mode (full module):**

```markdown
## Module Gap Analysis: {module}
**Features scanned**: {count}
**Unique patterns in features**: {count}
**Patterns in step-definitions**: {count}

### Coverage: {percentage}%

### Gaps by Priority

#### Critical (blocks test execution)
[Steps that appear in @smoke or @critical tagged scenarios]

#### High (appears in 3+ features)
[Steps that are used frequently but missing]

#### Low (appears in 1-2 features)
[Steps that are rarely used]

### Recommended Actions
1. Create {ClassName}.java with {N} methods — covers {M} features
2. Extend {ExistingClass}.java with {N} methods — covers {M} features
...
```

## Output

Return the gap report to the main orchestrator. The orchestrator then either:
- Presents the report to the user (gap-analysis mode)
- Feeds the GAP list to the Code Generator agent (from-feature mode)

## Edge Cases

- **Scenario Outline steps**: Replace `<placeholder>` with `{string}` before matching
- **Data tables**: Steps with DataTable should match patterns that accept `DataTable` param
- **Doc strings**: Steps followed by `"""` blocks should match patterns with `String` param
- **Background steps**: Include these — they execute for every scenario
- **Step with state variables**: `${&G:VAR}` in step text is runtime interpolation;
  treat the whole `${...}` expression as a string parameter for matching purposes
