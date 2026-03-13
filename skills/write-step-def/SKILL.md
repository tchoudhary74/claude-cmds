---
name: write-step-def
description: >
  Generate Java/Cucumber step definitions for OCC's RNS test automation framework
  (com.theocc.raf.automation). Use this skill whenever the user needs to create, extend,
  or refactor step definition classes — including writing new @Given/@When/@Then methods,
  adding reusable helper utilities, wiring Spring-managed state, or converting raw Gherkin
  patterns into compilable Java. Also trigger when the user says "new step", "step def",
  "step definition", "glue code", "missing step", "undefined step", "snippet", or references
  the raf-automation / step-definitions repo. Works in tandem with the write-feature skill:
  when write-feature flags a pattern gap, this skill fills it. Supports sub-agent delegation
  for parallel analysis of existing steps, pattern gap detection, and PR-ready code generation.
arguments:
  - name: mode
    description: >
      Generation mode. One of:
        new-class     — Create a full new step definition class
        add-steps     — Add methods to an existing step definition class
        from-feature  — Scan a .feature file, find undefined steps, generate stubs
        refactor      — Refactor/optimize existing step definitions
        gap-analysis  — Audit feature files against step library, report gaps
    required: true
  - name: module
    description: Target module context (risk/clearing/sdp/ui) — determines package, imports, and patterns
    required: true
  - name: description
    description: What the step(s) should do, or path to a .feature file (for from-feature mode)
    required: true
  - name: class_path
    description: Existing step definition class path (required for add-steps and refactor modes)
    required: false
  - name: feature_path
    description: Path to .feature file to scan (required for from-feature mode)
    required: false
  - name: gherkin_snippets
    description: Raw Gherkin step text to convert (optional — paste undefined steps)
    required: false
---

# Write Step Definition — OCC RNS Automation

> **Philosophy**: Step definitions are the contract between Gherkin and Java.
> Every generated method must compile, follow the team's conventions exactly,
> and be immediately mergeable via PR with zero surprises.

## Quick Reference — When to Read Sub-Files

| Situation | Read |
|-----------|------|
| Need to understand existing step patterns / annotations | `references/step-patterns.md` |
| Creating a brand-new class | `templates/step-class-template.md` |
| Working with Spring context / state management | `references/spring-wiring.md` |
| Delegating to sub-agents (Claude Code only) | `agents/` directory |
| Gap analysis across many features | `agents/gap-analyzer.md` |

---

## CRITICAL CONSTRAINTS

**These are non-negotiable. Violating any of them produces code that will fail CI.**

1. **Package conventions are sacred.**
   Step definitions live in `com.theocc.raf.automation.stepdefs.{domain}`.
   Domain maps from module: `risk` → `risk`, `clearing` → `clearing`,
   `sdp` → `sdp`, `ui` → `ui`.

2. **Annotation regex must be exact Cucumber Expression or Regex.**
   - Prefer Cucumber Expressions (`{string}`, `{int}`, `{word}`) over raw regex
     when the existing codebase uses them.
   - If existing code uses regex (`"^...$"`), match that style in the same class.
   - **Never mix** Cucumber Expressions and regex in the same class file.

3. **Spring context is mandatory.**
   Every step class is Spring-managed (`@Component` or detected via `@ContextConfiguration`).
   State sharing uses the project's `TestContext` / `ScenarioContext` bean — never static fields.

4. **No duplicate patterns.**
   Before writing ANY step method, search the entire step-definitions repo for
   that regex/expression. If it exists, do NOT recreate it. Instead, tell the user
   which class already owns it and suggest reuse or extension.

5. **One concern per class.**
   Don't pile unrelated steps into a catch-all class. If the steps span two domains
   (e.g., API setup + DB validation), create or extend two classes.

6. **Mandatory Javadoc on public step methods.**
   At minimum: one-line purpose, `@param` for each captured group, which feature
   files consume it (if known).

---

## EXECUTION WORKFLOW

### STEP 0 — Determine Mode & Inputs

```
mode = {mode argument}

IF mode == "from-feature":
    Require {feature_path} — read the .feature file, extract all step lines.
    For each step, search existing step-definitions repo for a matching pattern.
    Partition into: MATCHED (already implemented) vs UNMATCHED (need new code).
    Generate stubs only for UNMATCHED steps.

IF mode == "new-class":
    Require {module} and {description}.
    Read templates/step-class-template.md for the skeleton.
    Generate a full class with package, imports, annotations, and methods.

IF mode == "add-steps":
    Require {class_path} — read the existing class.
    Preserve ALL existing code. Append new methods at the end (before closing brace).
    Match the annotation style (regex vs Cucumber Expression) already in the file.

IF mode == "refactor":
    Require {class_path} — read the existing class.
    Identify: dead code, duplicate patterns, overly broad regex, missing Javadoc.
    Produce a refactored version with a diff summary.

IF mode == "gap-analysis":
    Require {module}.
    Scan ALL .feature files in {module}-features/.
    Cross-reference against step-definitions repo.
    Output a report: which steps are undefined, grouped by domain.
    → Delegate to agents/gap-analyzer.md if sub-agents available.
```

### STEP 1 — Discover Existing Patterns (MANDATORY)

**Why**: The step-definitions repo is the single source of truth. You must never
generate a method whose pattern already exists there.

**Search strategy (tiered, stop when you have enough context):**

```
Tier 1 — Exact class match:
  Search for classes in the same domain package.
  Example: com.theocc.raf.automation.stepdefs.ui.notification.*

Tier 2 — Keyword grep:
  Extract verbs/nouns from {description}.
  grep -rn "{keyword}" --include="*.java" src/main/java/.../stepdefs/

Tier 3 — Annotation grep:
  grep -rn "@Given\|@When\|@Then\|@And" --include="*.java" src/main/java/.../stepdefs/{domain}/
  Parse out all registered patterns into a local index.

Tier 4 — Full repo scan (gap-analysis mode only):
  Build a complete pattern→class index across the entire stepdefs package.
```

**Output of this step**: A list of EXISTING patterns relevant to the user's request.
Present this to the user: "These steps already exist — I'll reuse them, not duplicate."

### STEP 2 — Design the Step Signatures

For each NEW step needed:

1. **Write the Gherkin line first** (exactly as it would appear in a .feature file).
2. **Derive the annotation pattern** from the Gherkin line.
3. **Derive the Java method name** — use camelCase, descriptive, starts with a verb.
4. **Derive the parameters** — map each captured group to a typed Java parameter.
5. **Determine the method body strategy**:
   - Delegates to a framework utility? → Call the utility.
   - Needs WebDriver interaction? → Inject Page Object, call its methods.
   - Needs REST call? → Use the project's `RestClient` wrapper.
   - Needs DB query? → Use the project's `DatabaseHelper`.
   - Needs Kafka? → Use the project's `KafkaHelper`.
   - Pure assertion? → Use `AssertionHelper` or direct JUnit/Hamcrest.

**Present the design table to the user before generating code:**

```
| # | Gherkin Step                              | Pattern                                  | Method Name              | Params          | Body Strategy     | Exists? |
|---|-------------------------------------------|------------------------------------------|--------------------------|-----------------|-------------------|---------|
| 1 | Given rest client is created with "X"     | rest client is created with {string}     | createRestClient         | String propFile | RestClient.init() | ✅ YES  |
| 2 | When user sends POST to "/api/v2/notify"  | user sends POST to {string}             | sendPostRequest          | String endpoint | RestClient.post() | ❌ NEW  |
| 3 | Then validate response status is {int}    | validate response status is {int}        | validateResponseStatus   | int code        | AssertionHelper   | ❌ NEW  |
```

### STEP 3 — Generate Code

Read `templates/step-class-template.md` for the skeleton.
Read `references/spring-wiring.md` for injection patterns.
Read `references/step-patterns.md` for annotation conventions.

**Generation rules:**

1. **Imports**: Only import what you use. Group: java.*, javax.*, org.*, com.theocc.*.
2. **Class annotation**: `@Component` (or none if picked up via component scan config).
3. **Constructor injection** preferred over `@Autowired` fields (matches team style).
4. **Logging**: Use `private static final Logger log = LoggerFactory.getLogger(ClassName.class);`
5. **Step methods**: `public void`, annotated with `@Given`/`@When`/`@Then`.
6. **Method body**:
   - Start with `log.info(...)` describing the action.
   - Core logic delegating to framework utilities.
   - End with state storage if result is needed downstream: `testContext.set("KEY", value);`
7. **Error handling**: Let exceptions propagate (Cucumber reports them). Only catch
   if you need to enrich the error message.

### STEP 4 — Validate Generated Code (PRE-OUTPUT CHECKLIST)

Before presenting code to the user:

- [ ] Every `@Given`/`@When`/`@Then` pattern is unique across the repo
- [ ] No raw `Thread.sleep()` — use framework wait utilities
- [ ] No hardcoded test data — externalize to property files or step parameters
- [ ] Constructor injection used (not field `@Autowired`)
- [ ] Logger present and used
- [ ] Javadoc on every public method
- [ ] Package declaration matches `com.theocc.raf.automation.stepdefs.{domain}`
- [ ] Imports are minimal and sorted
- [ ] State is shared via `TestContext`, not static variables
- [ ] Method names are descriptive camelCase verbs

### STEP 5 — Output & Save

**File location convention:**
```
raf-automation/src/main/java/com/theocc/raf/automation/stepdefs/{domain}/{ClassName}.java
```

**For add-steps mode**: Show only the diff (new methods) plus the full updated file.

**For from-feature mode**: Group generated stubs by recommended class, with a summary:
```
📋 Feature scan: {feature_path}
   Total steps: 45
   Already implemented: 38
   New stubs needed: 7
   Recommended classes:
     - NotificationSteps.java (4 new methods)
     - FilterValidationSteps.java (3 new methods)
```

**For gap-analysis mode**: Output a markdown report:
```
📋 Gap Analysis: {module}-features
   Features scanned: 120
   Unique step patterns: 340
   Implemented: 312
   Missing: 28
   
   Top gaps by domain:
   1. notification (12 missing steps)
   2. subscription (8 missing steps)
   3. dashboard (5 missing steps)
   4. other (3 missing steps)
   
   [Detailed table follows...]
```

Save the generated file(s) and present with:
```
✅ Step definition saved to:
  {full_path}

📋 Summary:
  New methods: {count}
  Pattern conflicts: {count, should be 0}
  
📋 Next steps:
  1. Review Javadoc and adjust descriptions
  2. Wire any new Page Objects / utilities if referenced
  3. Run: mvn compile -pl raf-automation (verify compilation)
  4. Run: mvn test -pl raf-automation -Dcucumber.filter.tags="@your-tag"
  5. Raise PR against raf-automation repo
```

---

## SUB-AGENT ARCHITECTURE (Claude Code / Cowork)

When running in an environment with sub-agent support, the main orchestrator
can delegate to specialized agents for parallel work:

| Agent | File | Purpose |
|-------|------|---------|
| Pattern Scanner | `agents/pattern-scanner.md` | Scans step-def repo, builds pattern index |
| Gap Analyzer | `agents/gap-analyzer.md` | Cross-refs features ↔ steps, finds gaps |
| Code Generator | `agents/code-generator.md` | Generates Java code given a design table |
| PR Reviewer | `agents/pr-reviewer.md` | Reviews generated code against team standards |

**Orchestration flow with sub-agents:**

```
Main Agent (this skill)
  │
  ├─► [Parallel] Pattern Scanner → builds pattern index
  ├─► [Parallel] Feature Reader → extracts Gherkin steps
  │
  ├─► [Sequential] Main Agent: Merge results, identify gaps
  │
  ├─► [Parallel] Code Generator → produces Java for each new step class
  │
  └─► [Sequential] PR Reviewer → validates before output
```

**Without sub-agents** (Claude.ai): Execute all steps sequentially in the main
skill. This is slower but produces identical output.

---

## INTEGRATION WITH write-feature SKILL

These two skills are designed to work together:

```
User wants a new test:
  1. /write-feature ui new-feature "notification inbox filter"
     → Generates .feature file
     → Some steps may not exist yet
     → Output includes: "⚠️ These steps may need new definitions: [list]"

  2. /write-step-def from-feature ui "path/to/generated.feature"
     → Scans the feature file
     → Identifies which steps are already in raf-automation
     → Generates stubs for missing ones
     → User raises PR for new step defs

  Result: Feature file + step definitions, both following exact conventions.
```

When write-feature flags an unmatched step, it should suggest:
```
⚠️ Step pattern not found in reference features: "user filters by date range {string} to {string}"
   → Run: /write-step-def from-feature ui "{feature_path}" to generate the missing step definition
```

---

## ERROR HANDLING

**IF mode = "add-steps" AND class_path not provided:**
```
❌ ERROR: class_path is required for add-steps mode.
   Provide the full path to the existing step definition class.
   Example: raf-automation/src/main/java/com/theocc/raf/automation/stepdefs/ui/NotificationSteps.java
```

**IF mode = "from-feature" AND feature_path not provided:**
```
❌ ERROR: feature_path is required for from-feature mode.
   Provide the path to the .feature file to scan.
   Example: ui-features/src/test/resources/features/ovation/notifications/inbox/TC_12345.feature
```

**IF pattern collision detected:**
```
⚠️ COLLISION: Pattern "validate response status is {int}" already exists in:
   → ResponseValidationSteps.java (line 42)
   
   Options:
   1. Reuse the existing step (recommended)
   2. Extend the existing method to handle your case
   3. Create a more specific pattern to avoid collision
```

**IF no step-definitions repo found:**
```
⚠️ WARNING: Cannot locate raf-automation step definitions repo.
   Expected at: ./raf-automation/ or provide the path.
   
   Without the repo, generated code cannot be validated against existing patterns.
   Proceed with caution — manual dedup review required before PR.
```
