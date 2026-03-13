# Step Pattern Reference — OCC RNS Automation

## Annotation Styles

The codebase uses two annotation styles. **Never mix them within a single class.**

### Style A: Cucumber Expressions (Preferred for new classes)

```java
@Given("rest client is created with properties file {string}")
@When("user sends {word} request to {string}")
@Then("validate response status is {int}")
@Then("validate string {string} equals-to {string}")
```

**Built-in parameter types:**
- `{string}` — matches quoted text `"..."`, captures without quotes
- `{int}` — matches integer
- `{float}` — matches decimal number
- `{word}` — matches single word (no spaces)
- `{bigdecimal}` — matches decimal with arbitrary precision
- `{}` — anonymous, matches anything (avoid unless necessary)

### Style B: Regex (Legacy classes — match when extending)

```java
@Given("^rest client is created with properties file \"([^\"]*)\"$")
@When("^user sends (GET|POST|PUT|DELETE) request to \"([^\"]*)\"$")
@Then("^validate response status is (\\d+)$")
```

**When to use which:**
- New class → Cucumber Expressions (Style A)
- Adding to existing class → match whatever style the class already uses
- Regex is required when you need alternation (`GET|POST`) or complex matching

---

## Common Step Pattern Categories

### REST API Steps

```
Given rest client is created with properties file {string}
When {word} request is invoked to endpoint {string}
When {word} request is invoked to endpoint {string} with body {string}
Then save CONTEXT value from header {string} as {string}
Then save CONTEXT value from jsonPath {string} as {string}
Then validate CONTEXT is not empty
Then validate response status code is {int}
Then validate jsonPath {string} equals {string}
Then validate jsonPath {string} contains {string}
Then validate jsonPath {string} is not null
```

### Database Steps

```
Given database connection is created with properties file {string}
When query is executed with {string}
When query is executed with file {string}
Then save query result column {string} row {int} as {string}
Then validate query result is not empty
Then validate query result contains {string}
Then validate query result column {string} equals {string}
Then validate query result row count is {int}
```

### Kafka Steps

```
Given kafka consumer is created with properties file {string}
Given kafka producer is created with properties file {string}
When message is consumed from topic {string}
When message is published to topic {string} with payload {string}
Then validate consumed message contains {string}
Then validate consumed message jsonPath {string} equals {string}
Then save consumed message field {string} as {string}
```

### UI / Selenium Steps

```
Given user navigates to {string}
When user clicks on button {string}
When user clicks on element {string}
When user enters {string} in textbox {string}
When user enter username {string} in textbox {string} and enter password in textbox {string}
When user selects {string} from dropdown {string}
When user waits for element {string} to be visible
Then element {string} should be visible
Then element {string} should contain text {string}
Then validate page title is {string}
Then validate element {string} text equals {string}
```

### State Management Steps

```
Then save CONTEXT value {string} as LOCAL {string}
Then save CONTEXT value {string} as GLOBAL {string}
Then save stateKey {string} from LOCAL as GLOBAL {string}
Then validate stateKey {string} from LOCAL is not empty
Then validate stateKey {string} from GLOBAL equals {string}
Then validate string {string} equals-to {string}
```

### Logging Steps

```
Then log CONTEXT
Then log stateKey {string} from LOCAL
Then log stateKey {string} from GLOBAL
Then log message {string}
```

### Wait / Timing Steps

```
When user waits for {int} seconds
When user waits until element {string} is clickable
When user waits until element {string} is not visible
When user waits for page to load
```

---

## State Variable Syntax

In feature files, state variables use this syntax:
- `${&G:VARIABLE_NAME}` — references a GLOBAL state variable
- `${&L:VARIABLE_NAME}` — references a LOCAL state variable

In step definitions, these are resolved by the framework BEFORE the step
method is called. Your step method receives the resolved value as a plain String.

**You do NOT need to parse `${&G:...}` in step definition code.**
The framework's parameter resolver handles this transparently.

---

## Parameter Naming Conventions

| Cucumber Type | Java Type | Preferred Param Name |
|---------------|-----------|---------------------|
| {string} (property file) | String | propertiesFile |
| {string} (endpoint) | String | endpoint |
| {string} (JSON path) | String | jsonPath |
| {string} (element locator) | String | locator |
| {string} (state key) | String | stateKey |
| {string} (generic value) | String | value |
| {int} (status code) | int | statusCode |
| {int} (count) | int | count |
| {int} (row index) | int | rowIndex |
| {word} (HTTP method) | String | httpMethod |
| DataTable | DataTable | dataTable |

---

## Anti-Patterns to Avoid

1. **Overly broad patterns**: `@When("{string}")` — matches everything, causes ambiguity
2. **Hardcoded values in patterns**: `@When("user clicks Submit")` — not reusable
3. **Multiple actions in one step**: Keep steps atomic; one action per method
4. **Assertions in @When steps**: @When is for actions; @Then is for assertions
5. **Direct WebDriver calls**: Always go through Page Objects
6. **Static state**: Use TestContext, never static fields
7. **Swallowing exceptions**: Let them propagate for Cucumber reporting
