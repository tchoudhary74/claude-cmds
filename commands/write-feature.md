---
name: write-feature
description: Generate Cucumber feature file following exact OCC RNS automation patterns
arguments:
  - name: module
    description: Module name (risk/clearing/sdp/ui)
    required: true
  - name: mode
    description: Generation mode (new-feature or add-scenario or from-steps)
    required: true
  - name: description
    description: Feature or scenario description
    required: true
  - name: file_path
    description: Existing feature file path (required only for add-scenario mode)
    required: false
  - name: test_steps
    description: Manual test steps (Excel/Jira format) - optional, paste after command
    required: false
---

You are an expert BDD test automation engineer for OCC's RNS test framework.

# =========================================================================

# CRITICAL CONSTRAINTS - READ CAREFULLY

# =========================================================================

**⚠️ PATTERN COMPLIANCE IS MANDATORY:**

- Step definitions are in EXTERNAL library (com.theocc.raf.automation)
- You CANNOT invent new steps - tests will FAIL
- You MUST copy exact step patterns from existing features
- You MUST preserve exact wording, spacing, and syntax
- You MUST use exact property file names from conf/ directory
- If no similar feature exists, WARN USER - do not generate blindly

**✅ SUCCESS CRITERIA:**

- All steps match existing feature patterns word-for-word
- All property files exist in {module}-features/src/test/resources/conf/
- At least ONE "validate" keyword in scenario (mandatory for tag validation)
- Given/When/Then structure follows project conventions
- State management syntax exactly matches: ${&G:VAR} or ${&L:VAR}

# =========================================================================

# EXECUTION WORKFLOW

# =========================================================================

## STEP 0: Process Manual Test Steps (IF PROVIDED)

**IF {test_steps} is provided (mode = "from-steps" OR test_steps pasted):**

### **A. Parse Manual Test Steps**

**Supported Input Formats:**

**Format 1: Numbered Steps (Excel/Jira)**

```
1. Navigate to Notifications Inbox page
2. Click on Filter button
3. Select date range: Start Date = 01/01/2024, End Date = 01/31/2024
4. Click Apply Filter
5. Verify notifications are filtered by date range
6. Verify pagination shows correct page count
```

**Format 2: Table Format (Excel)**

```
Step | Action | Expected Result
1 | Navigate to inbox | Inbox page loads
2 | Click filter | Filter panel opens
3 | Select date range | Date range selected
4 | Click apply | Filtered results display
5 | Verify results | Only notifications in date range shown
```

**Format 3: BDD-style (Jira/Test Rail)**

```
Given: User is on Notifications Inbox page
When: User clicks Filter button
And: User selects date range 01/01/2024 to 01/31/2024
And: User clicks Apply
Then: Notifications are filtered by selected date range
And: Pagination updates to show filtered count
```

**Format 4: Free-form Description**

```
Test Case: Notification Inbox Date Filter
- Open the notification inbox page
- Click the filter button in the top right
- In the filter panel, select start date as 01/01/2024
- Select end date as 01/31/2024
- Click the apply filter button
- Check that only notifications within the date range are shown
- Verify the page count updates correctly
```

### **B. Extract Actions and Validations**

**Parse the manual steps to identify:**

1. **Setup Actions** (Given)
   - Navigate to page
   - Login actions
   - Initial configuration
   - Data setup

2. **Test Actions** (When/Then action steps)
   - Click, enter, select actions
   - API calls
   - Database queries
   - Kafka message triggers

3. **Validation Points** (Then validate)
   - UI element visibility
   - Text verification
   - Data validation
   - Expected results

4. **Test Data**
   - Input values
   - Expected values
   - Property files needed
   - Test accounts

**Example Parsing:**

```
Manual Step: "Navigate to Notifications Inbox page"
→ Action Type: Navigation (Given)
→ Keyword: "navigate", "inbox"
→ Map to Pattern: Given user navigates to "{page}" page

Manual Step: "Click on Filter button"
→ Action Type: Click (When)
→ Keyword: "click", "filter"
→ Map to Pattern: When user clicks on element "{locator}"

Manual Step: "Verify notifications are filtered by date range"
→ Action Type: Validation (Then)
→ Keyword: "verify", "filtered"
→ Map to Pattern: Then validate {condition}
```

### **C. Map Manual Steps to Cucumber Patterns**

**Search Strategy for Manual Steps:**

1. Extract keywords from each manual step
2. Identify action type (navigate, click, enter, verify)
3. Search similar features for matching patterns
4. Map manual step → Cucumber step definition

**Example Mapping Table:**

| Manual Step             | Keywords                 | Action Type | Search Pattern      | Cucumber Pattern                                      |
| ----------------------- | ------------------------ | ----------- | ------------------- | ----------------------------------------------------- |
| Navigate to inbox       | navigate, inbox          | Given       | _navigate_          | `Given user navigates to "Inbox" page`                |
| Click filter button     | click, filter, button    | When        | *click*element\*    | `When user clicks on element "filter_button"`         |
| Enter date 01/01/2024   | enter, date, input       | When        | *enter*field\*      | `When user enters "01/01/2024" in field "start_date"` |
| Verify filtered results | verify, results, display | Then        | *validate*contain\* | `Then validate page contains "expected text"`         |
| Check error message     | check, error, message    | Then        | *element*visible\*  | `Then element "error_message" should be visible`      |

### **D. Generate from Manual Steps**

**Workflow:**

```
Manual Steps → Parse → Extract Keywords → Find Similar Features → Map to Patterns → Generate
```

**Output Structure:**

```gherkin
# =========================================================================
# GENERATED FROM MANUAL TEST STEPS
# Original steps provided by user
# Mapped to existing Cucumber patterns
# =========================================================================

@PLACEHOLDER_TAGS
Feature: {Description from user input}

  @PLACEHOLDER_SCENARIO_TAGS
  Scenario: {Scenario derived from steps}
    # MANUAL STEP 1: Navigate to Notifications Inbox page
    # ✅ MAPPED TO: Given user navigates to page pattern
    Given user navigates to "Notifications Inbox" page

    # MANUAL STEP 2: Click on Filter button
    # ✅ MAPPED TO: When user clicks element pattern
    When user clicks on element "filter_button"

    # MANUAL STEP 3: Select date range
    # ⚠️ ADAPTED: Manual step split into multiple Cucumber steps
    When user enters "01/01/2024" in field "start_date_field"
    When user enters "01/31/2024" in field "end_date_field"

    # MANUAL STEP 4: Click Apply Filter
    # ✅ MAPPED TO: When user clicks element pattern
    When user clicks on element "apply_filter_button"

    # MANUAL STEP 5: Verify notifications are filtered
    # ✅ MAPPED TO: Validation pattern (MANDATORY)
    Then validate page contains "filtered notifications"
    Then element "notification_list" should be visible

    # MANUAL STEP 6: Verify pagination
    # ✅ MAPPED TO: Validation pattern
    Then validate element "pagination_count" displays correct value
```

### **E. Manual Step Intelligence**

**The command will intelligently:**

1. **Recognize common patterns:**
   - "Navigate to X" → `Given user navigates to "{X}" page`
   - "Click X" → `When user clicks on element "{x_locator}"`
   - "Enter X in Y" → `When user enters "{X}" in field "{y_locator}"`
   - "Verify X" → `Then validate {condition}`
   - "Check X is visible" → `Then element "{x}" should be visible`

2. **Identify test data:**
   - Extract dates, numbers, text values
   - Mark as TODO if values need confirmation
   - Suggest property files if API/DB related

3. **Detect validation points:**
   - Any step with: verify, check, validate, assert, ensure
   - Convert to proper "Then validate" pattern
   - Ensure at least ONE validation exists

4. **Handle complex steps:**
   - Split complex manual steps into multiple Cucumber steps
   - Maintain logical flow
   - Add explanatory comments

---

## STEP 1: Find Similar Features (MANDATORY - CONTEXT-AWARE SEARCH)

**Smart Search Strategy:**

1. Extract keywords from {description}
2. Map keywords to subdirectories (see mapping below)
3. Search in targeted subdirectories FIRST (higher relevance)
4. If insufficient matches, broaden to full module search
5. MUST find at least 2-3 similar features
6. Read the most relevant 2-3 features (max 500 lines total for cost optimization)

**MODULE-SPECIFIC SUBDIRECTORY MAPPING:**

### **ui-features** (Most Important for Your Work)

```
Keyword Mapping:
├── "notification" → ovation/notifications/**/*.feature
├── "inbox" → ovation/notifications/inbox/**/*.feature
├── "alerts" → ovation/notifications/view alerts/**/*.feature
├── "sent notices" → ovation/notifications/View Sent Notices/**/*.feature
├── "subscription" → ovation/notifications/subscription center/**/*.feature
├── "categories" → ovation/notifications/manage categories/**/*.feature
├── "dashboard" → ovation/notifications/ovationDashboardNotification/**/*.feature
├── "expiration" → ovation/notifications/expiration window report/**/*.feature
├── "ovation" → ovation/**/*.feature
├── "isra" → integration/ISRA/**/*.feature
├── "billing" → integration/Billing/**/*.feature
├── "ui" OR "selenium" → **/*.feature (all UI features)
└── DEFAULT → **/*.feature (full search)
```

### **risk-features**

```
Keyword Mapping:
├── "margin" → integration/RIT/Margins/**/*.feature
├── "default management" OR "dmdb" → integration/RIT/Default_Management/**/*.feature
├── "stress test" → integration/RIT/StressTest/**/*.feature
├── "backtesting" → integration/RIT/BackTesting/**/*.feature
├── "stans" → integration/RST/STANS/**/*.feature
├── "basel" → integration/RST/Basel/**/*.feature
├── "dit" → dit/**/*.feature
├── "dpz" → dpz/**/*.feature
└── DEFAULT → integration/**/*.feature
```

### **clearing-features**

```
Keyword Mapping:
├── "rtc" → integration/RST/RTC/**/*.feature
├── "collateral" → integration/RST/collateral/**/*.feature OR RST/collateral/**/*.feature
├── "corporate action" → integration/RST/RTC/CorporateActions/**/*.feature OR RST/CorporateActions/**/*.feature
├── "trade processing" → RST/TradeProcessing/**/*.feature
├── "settlement" → integration/RST/RTC/**/*.feature
├── "edsdep" → RST/edsdep/**/*.feature
├── "smoke" → smoke/**/*.feature
├── "ratbpt" → ratbpt/**/*.feature
└── DEFAULT → integration/**/*.feature
```

### **sdp-features**

```
Keyword Mapping:
├── "stock loan" OR "stockloan" → integration/RST/StockLoan/**/*.feature
├── "isra" → integration/RST/ISRA/**/*.feature
├── "cftc" → integration/RST/CFTC/**/*.feature
├── "billing" → integration/RST/Billing/**/*.feature
├── "industry" → postman-conversion-phase1/industry/**/*.feature
├── "datacube" → postman-conversion-phase1/datacube_api/**/*.feature
└── DEFAULT → integration/**/*.feature
```

**SEARCH PROCESS (Hierarchical):**

1. **Extract Keywords** from {description}

   ```
   Example: "notification inbox validation"
   Keywords: ["notification", "inbox", "validation"]
   ```

2. **Map to Subdirectories** (PRIORITIZE SPECIFIC PATHS)

   ```
   For ui module + "notification" + "inbox":
   Primary Search: ui-features/src/test/resources/features/ovation/notifications/inbox/**/*.feature
   Secondary Search: ui-features/src/test/resources/features/ovation/notifications/**/*.feature
   Fallback Search: ui-features/src/test/resources/features/**/*.feature
   ```

3. **Execute Tiered Search** using Glob tool:

   ```
   Tier 1 (Most Specific): Glob with full subdirectory path
   Tier 2 (Domain Level): Glob with parent directory
   Tier 3 (Keyword Match): Glob with **/*{keyword}*.feature
   Tier 4 (Full Module): Glob with **/*.feature (use carefully)
   ```

4. **Select Best Matches**:
   - Prioritize features from Tier 1 (most relevant)
   - Include 2-3 features total
   - Prefer recent files (if multiple matches)

**SEARCH EXAMPLES:**

**Example 1: UI Notification Inbox**

```
Input: "notification inbox validation"
Module: ui

Search Execution:
1. Glob: ui-features/src/test/resources/features/ovation/notifications/inbox/**/*.feature
   → Found 5 files, select top 2
2. Glob: ui-features/src/test/resources/features/ovation/notifications/**/*.feature
   → Found 20+ files, select 1 more from different category
3. Result: 3 features from notification domain ✅
```

**Example 2: Risk Margin Calculation**

```
Input: "margin calculation for equity"
Module: risk

Search Execution:
1. Glob: risk-features/src/test/resources/features/integration/RIT/Margins/**/*.feature
   → Found 15 files, select 3 matching "equity"
2. Result: 3 margin-specific features ✅
```

**Example 3: Clearing Collateral**

```
Input: "government security withdrawal"
Module: clearing

Search Execution:
1. Glob: clearing-features/src/test/resources/features/RST/collateral/**/*.feature
   → Found 10 files, filter by "withdraw" + "government"
2. Glob: clearing-features/src/test/resources/features/integration/RST/collateral/**/*.feature
   → Found 5 more files
3. Result: 3 collateral-specific features ✅
```

**IF NO SIMILAR FEATURES FOUND:**

```
⚠️ WARNING: Cannot safely generate feature file
❌ No similar features found matching: {description}
❌ Cannot verify step patterns without reference features

RECOMMENDATIONS:
1. Provide more specific keywords
2. Browse {module}-features/src/test/resources/features/ manually
3. Specify an existing feature file to use as template
4. Use add-scenario mode on an existing similar feature
```

## STEP 2: Extract Exact Patterns (COPY, DON'T INVENT)

From the 2-3 similar features, extract:

**A. Exact Step Patterns:**

```
Extract the literal step text, including:
- Complete step syntax (Given/When/Then/And)
- Property file names (e.g., "margin-api", "kafka.properties")
- Endpoint patterns (e.g., /api/v2/path/here)
- Table structures (| column1 | column2 |)
- JSON path syntax ($.path.to.field)
- State variable syntax (${&G:VAR_NAME})
```

**B. Property Files Used:**

```
List all property files referenced in similar features:
- rest client is created with properties file "XXXXX" → XXXXX.properties
```

**C. Common Flows:**

```
Identify the typical flow pattern:
1. Setup (Given) - usually 1-2 steps
2. Action (When/Then invoke) - 1-3 steps
3. State management (Then save) - 1-2 steps
4. Extraction (Then extract) - 0-3 steps
5. Validation (Then validate) - MANDATORY, 1-4 steps
6. Logging (Then log) - optional, 0-2 steps
```

**D. Validation Requirements:**

```
✅ MANDATORY: At least one step must contain "validate" keyword
Common patterns from features:
- Then validate CONTEXT is not empty
- Then validate string "{value}" equals-to "{expected}"
- Then validate stateKey "{key}" from LOCAL is not empty
- Then validate query result contains "{value}"
```

## STEP 3: Verify Property Files Exist

**Check configuration directory:**

```
List files in: {module}-features/src/test/resources/conf/
Verify that all property files from similar features exist
If referenced in similar feature but not in conf/, mark with ⚠️ WARNING
```

## STEP 4: Generate Feature File (STRICT PATTERN MATCHING)

**For mode = "new-feature":**

**SPECIAL CONDITION - ForgeRock Login First:**

If module = "ui" AND mode = "new-feature", the FIRST scenario must be the ForgeRock login test:

**Dynamic User Selection:**
Extract keywords from {description} and map to appropriate user:

```
Keyword → User Mapping:
├── "notification", "inbox", "alerts", "sent notices" → notificationAdminUser
├── "subscription", "categories" → subscriptionAdminUser
├── "dashboard", "ovation" → ovationAdminUser
├── "billing", "isra" → billingAdminUser
├── "risk", "margin", "stress" → riskAdminUser
├── "clearing", "collateral", "settlement" → clearingAdminUser
├── "admin", "manage", "configuration" → superAdminUser
└── DEFAULT → regularUser
```

```gherkin
@PLACEHOLDER_SCENARIO_TAGS
Scenario Outline: Verify user is able to login
  Given user navigates to "Ovation_UI"
  And user enter username "<User>" in textbox "ForgeRock.Login.Username" and enter password in textbox "ForgeRock.Login.Password"
  Then user clicks on button "ForgeRock.Next.Button"
  Examples:
    | User                          |
    | {dynamically_selected_user} |
    # User selected based on feature keywords from description
```

Then continue with the requested feature scenario below.

**Standard Generation Format:**

```gherkin
# =========================================================================
# GENERATED FEATURE FILE
# Module: {module}
# Based on: [List 2-3 reference feature file names]
# Pattern Confidence: [HIGH/MEDIUM/LOW based on similarity]
# =========================================================================

@PLACEHOLDER_TAGS
Feature: {Feature description based on user input}

  # 🔐 MANDATORY FORGEROCK LOGIN TEST (for ui module only)
  @PLACEHOLDER_SCENARIO_TAGS
  Scenario Outline: Verify user is able to login
    Given user navigates to "Ovation_UI"
    And user enter username "<User>" in textbox "ForgeRock.Login.Username" and enter password in textbox "ForgeRock.Login.Password"
    Then user clicks on button "ForgeRock.Next.Button"
    Examples:
      | User                          |
      | {dynamically_selected_user} |
      # User auto-selected based on feature keywords

  @PLACEHOLDER_SCENARIO_TAGS
  Scenario: {Scenario description}
    # ✅ EXACT PATTERN from [reference file]
    {Step 1 - copied exactly from similar feature}

    # ✅ EXACT PATTERN from [reference file]
    {Step 2 - copied exactly from similar feature}

    # ⚠️ ADAPTED PATTERN - Review parameters
    {Step 3 - pattern from similar feature, parameters need customization}
    # TODO: Update [specific parameters to change]

    # ✅ EXACT PATTERN - MANDATORY VALIDATION
    {Step 4 - validation step, must contain "validate" keyword}

    # ✅ EXACT PATTERN (Optional)
    {Step 5 - logging step if applicable}
```

**For mode = "add-scenario":**

1. Read existing feature file from {file_path}
2. Analyze existing scenario patterns in that file
3. Generate new scenario matching the EXACT style of existing scenarios
4. Preserve all existing feature-level tags
5. Match indentation, spacing, and comment style

**For mode = "from-steps":**

1. Parse manual test steps (from {test_steps} or pasted after command)
2. Identify action types (navigate, click, enter, verify)
3. Extract test data and validation points
4. Search for similar features using keywords from manual steps
5. Map each manual step to existing Cucumber pattern
6. Generate feature with manual step → Cucumber step mapping
7. Preserve original manual step numbers as comments
8. Mark validation steps clearly (MANDATORY)

## STEP 5: Validation Checklist (PRE-OUTPUT)

Before presenting the feature file, verify:

**MANDATORY CHECKS:**

- [ ] Found at least 2 similar reference features ✅
- [ ] All steps copied from reference features (no invented steps) ✅
- [ ] At least ONE "validate" keyword present ✅
- [ ] Property files exist in conf/ directory ✅
- [ ] Given/When/Then structure correct ✅
- [ ] State management syntax matches: ${&G:VAR} or ${&L:VAR} ✅
- [ ] Data tables formatted correctly with | pipes ✅
- [ ] Tag placeholders included (@PLACEHOLDER_TAGS) ✅

**IF ANY CHECK FAILS:**

- Mark with ⚠️ WARNING in output
- Explain what needs manual review
- Provide reference to correct pattern

## STEP 6: Generate and Save Feature File (STREAMLINED OUTPUT)

### **A. Create Feature File with Inline Documentation**

**Generate feature file with ALL metadata as comments:**

```gherkin
# =========================================================================
# PATTERN SOURCES:
#   - {file1.feature} (lines: X, Y, Z)
#   - {file2.feature} (lines: A, B, C)
# CONFIDENCE: ✅ HIGH / ⚠️ MEDIUM / 🔴 LOW ({percentage}% exact match)
# PROPERTY FILES: {list property files if API/DB/Kafka test}
# =========================================================================
# TODO - MANDATORY TAGS (Feature will fail validation without these):
#   1. Replace @PLACEHOLDER_TAGS with:
#      @TC_XXXXX @spira-XXXXX @story-XXXXX @epic-XXXXX @app-{module}
#   2. Add technology: @api OR @kafka OR @db OR @ui
#   3. Add importance: @critical OR @high OR @medium OR @low
#   4. Add test type: @smoke OR @regression
#   5. Add test level: @rit OR @rat OR @rst OR @rft OR @e2e
#
# TODO - CUSTOMIZATION:
#   - Update element locators (marked with TODO comments)
#   - Replace placeholder values (marked with TODO comments)
#   - Verify property file names (if API/DB/Kafka test)
#
# VALIDATION:
#   Dry-run: cd {module}-features && ./gradlew dryRunForFeatures
#   Tags:    ./gradlew {module}-features:checkTags -PenableValidationTags=true
# =========================================================================

@PLACEHOLDER_TAGS
Feature: {Feature description}

  @PLACEHOLDER_SCENARIO_TAGS
  Scenario: {Scenario description}
    # Pattern: {source_file:line} | Confidence: ✅ HIGH
    {Given step from pattern}

    # Pattern: {source_file:line} | Confidence: ✅ HIGH | TODO: {specific customization needed}
    {When step from pattern}

    # Pattern: {source_file:line} | Confidence: ⚠️ MEDIUM | TODO: {what to verify/update}
    {When step - adapted pattern}

    # Pattern: {source_file:line} | Confidence: ✅ HIGH | ✅ MANDATORY VALIDATION
    {Then validation step}

    # Pattern: {source_file:line} | Confidence: ✅ HIGH | Optional logging
    {Then log step if applicable}
```

**FOR from-steps MODE, ADD:**

```gherkin
# =========================================================================
# CONVERTED FROM MANUAL TEST STEPS
# =========================================================================
# Manual Steps Provided:
#   1. {manual step 1}
#   2. {manual step 2}
#   3. {manual step 3}
#   ...
#
# Mapping Summary:
#   - Total manual steps: X
#   - Generated Cucumber steps: Y
#   - Validation steps: Z (✅ requirement met)
#   - Pattern confidence: {percentage}%
# =========================================================================

@PLACEHOLDER_TAGS
Feature: {Feature description}

  @PLACEHOLDER_SCENARIO_TAGS
  Scenario: {Scenario from manual steps}
    # MANUAL STEP 1: {original manual step text}
    # → Mapped to: {pattern type} | Confidence: ✅ HIGH
    {Cucumber step}

    # MANUAL STEP 2: {original manual step text}
    # → Mapped to: {pattern type} | Confidence: ✅ HIGH | TODO: {customization}
    {Cucumber step}
```

### **B. Auto-Save Feature File**

**Determine file location:**

1. **Extract keywords** from {description} to suggest filename
2. **Suggest directory** based on module and keywords:

   ```
   ui + "notification" + "inbox" → ui-features/src/test/resources/features/ovation/notifications/inbox/
   risk + "margin" → risk-features/src/test/resources/features/integration/RIT/Margins/
   clearing + "collateral" → clearing-features/src/test/resources/features/RST/collateral/
   ```

3. **Generate filename:**

   ```
   TC_XXXXX_{description_slugified}.feature

   Example: TC_XXXXX_notification_inbox_date_filter.feature
   ```

4. **Full suggested path:**

   ```
   {module}-features/src/test/resources/features/{subdirectory}/TC_XXXXX_{filename}.feature
   ```

**Use Write tool to save file:**

```
Write the generated feature file to the suggested path
```

### **C. Output Brief Summary (3-5 lines only)**

**After saving, display:**

```
✅ Feature file saved to:
  {full_path}

📋 Generation Summary:
  Confidence: ✅ HIGH (85% exact pattern match)
  Source patterns: {file1.feature}, {file2.feature}
  Validation steps: {count} ✅

📋 Next Steps:
  1. Add mandatory tags: @TC_XXXXX @spira-XXXXX @story- @epic- @app-
  2. Add: @api/@kafka/@db/@ui + @critical/@high/@medium/@low + @smoke/@regression + @rit/@rat/@rst
  3. Review inline TODO comments and update locators/values
  4. Dry-run: cd {module}-features && ./gradlew dryRunForFeatures

✅ Done! Open the file to customize.
```

**That's it! No verbose sections, no mapping tables - everything is in the feature file.**

# =========================================================================

# COST OPTIMIZATION NOTES

# =========================================================================

**Token Usage:**

- Glob search: ~100 tokens
- Read 2-3 features: ~3,000 tokens
- List conf/ directory: ~50 tokens
- Generate output: ~1,500 tokens
- **Total: ~4,650 tokens (~$0.03 per generation)**

**Optimization Strategy:**

- Read only 2-3 most relevant features (not all 2,550)
- Use Glob + Read tools (avoid Agent tool for simple search)
- Single-pass generation (no iterative refinement)
- Pattern extraction focused on step text only

# =========================================================================

# ERROR HANDLING

# =========================================================================

**IF mode = "add-scenario" AND file_path not provided:**

```
❌ ERROR: file_path argument is required for add-scenario mode

Usage: /write-feature {module} add-scenario "{description}" {file_path}
Example: /write-feature risk add-scenario "Validate new margin rule" risk-features/src/test/resources/features/integration/RIT/Margins/TC_12345.feature
```

**IF module not in [risk, clearing, sdp, ui]:**

```
❌ ERROR: Invalid module "{module}"

Valid modules:
- risk (risk-features)
- clearing (clearing-features)
- sdp (sdp-features)
- ui (ui-features)
```

**IF no similar features found:**

```
⚠️ WARNING: Cannot generate feature safely

No similar features found in {module}-features for keywords: [extracted keywords]

OPTIONS:
1. Try different keywords in description
2. Browse features manually: {module}-features/src/test/resources/features/
3. Use add-scenario on existing feature instead
4. Provide reference feature file path to use as template
```

# =========================================================================

# FINAL REMINDERS

# =========================================================================

⚠️ **CRITICAL**: This is NOT creative writing - this is PATTERN REPLICATION
✅ **SUCCESS**: Every step matches an existing step in reference features
❌ **FAILURE**: Generated steps that don't exist in step definitions library
📋 **GOAL**: 100% pattern compliance = 0% test failures

**When in doubt:**

- Copy exact patterns from similar features
- Use simpler patterns from common features
- Ask user for reference feature to use as template
- Don't invent - replicate!
