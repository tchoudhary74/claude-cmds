# Code Generator Agent

> **Role**: Given a design table of step signatures (from the main orchestrator),
> produce compilable Java step definition code that exactly follows OCC RNS conventions.

## Trigger

Spawned by the main orchestrator after STEP 2 (Design the Step Signatures).
Receives a structured design and produces Java source files.

## Inputs

- `design_table`: Array of step designs, each containing:
  - `gherkin`: The Gherkin step text
  - `pattern`: The Cucumber annotation pattern
  - `pattern_style`: "regex" or "cucumber_expression"
  - `method_name`: Java method name
  - `params`: Array of `{type, name}` pairs
  - `body_strategy`: Which framework utility to delegate to
  - `target_class`: Class to add this method to (existing or new)
  - `target_domain`: Package domain (ui/risk/clearing/sdp)
- `existing_classes`: Map of class_path → current source code (for add-steps)
- `module`: Target module

## Code Generation Rules

### Class Structure (for new classes)

```java
package com.theocc.raf.automation.stepdefs.{domain};

// === Standard imports (include only what's used) ===
import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

// === Framework imports (based on body_strategy) ===
// RestClient → import com.theocc.raf.automation.rest.RestClient;
// DatabaseHelper → import com.theocc.raf.automation.db.DatabaseHelper;
// KafkaHelper → import com.theocc.raf.automation.kafka.KafkaHelper;
// TestContext → import com.theocc.raf.automation.context.TestContext;
// Page Objects → import com.theocc.raf.automation.pages.{domain}.*;
// Assertions → import static org.hamcrest.MatcherAssert.assertThat;
//              import static org.hamcrest.Matchers.*;

/**
 * Step definitions for {description}.
 *
 * <p>Covers Gherkin steps related to {domain summary}.
 * Used by feature files in: {module}-features/src/test/resources/features/{subdirectory}/
 *
 * @author OCC RNS Automation
 * @since {date}
 */
@Component
public class {ClassName} {

    private static final Logger log = LoggerFactory.getLogger({ClassName}.class);

    private final TestContext testContext;
    // Other injected dependencies...

    public {ClassName}(TestContext testContext) {
        this.testContext = testContext;
    }

    // === Step definitions below ===
}
```

### Method Generation

For each entry in design_table, generate a method following this template:

```java
    /**
     * {One-line description of what this step does}.
     *
     * @param {paramName} {description of param}
     * @see {FeatureFile} — {scenario name if known}
     */
    @{Type}("{pattern}")
    public void {methodName}({paramType} {paramName}) {
        log.info("{Human-readable action description}: {}", {paramName});
        
        // Body based on body_strategy
        {generated_body}
    }
```

### Body Strategy Templates

**RestClient (API steps):**
```java
    @When("user sends {word} request to {string}")
    public void sendRequest(String method, String endpoint) {
        log.info("Sending {} request to: {}", method, endpoint);
        var response = testContext.get("restClient", RestClient.class)
            .request(method, endpoint);
        testContext.set("response", response);
        testContext.set("statusCode", response.getStatusCode());
    }
```

**UI Action (Selenium steps):**
```java
    @When("user clicks on element {string}")
    public void clickElement(String locator) {
        log.info("Clicking on element: {}", locator);
        var page = testContext.get("currentPage", BasePage.class);
        page.clickElement(locator);
    }
```

**UI Input (form interaction):**
```java
    @When("user enters {string} in field {string}")
    public void enterInField(String value, String fieldLocator) {
        log.info("Entering '{}' in field: {}", value, fieldLocator);
        var page = testContext.get("currentPage", BasePage.class);
        page.enterText(fieldLocator, value);
    }
```

**Database (query steps):**
```java
    @Then("validate query result for {string} contains {string}")
    public void validateQueryResult(String queryKey, String expected) {
        log.info("Validating query '{}' contains: {}", queryKey, expected);
        var dbHelper = testContext.get("dbHelper", DatabaseHelper.class);
        String result = dbHelper.executeQuery(testContext.get(queryKey, String.class));
        assertThat("Query result should contain expected value",
            result, containsString(expected));
    }
```

**Kafka (messaging steps):**
```java
    @When("message is published to topic {string}")
    public void publishToTopic(String topic) {
        log.info("Publishing message to Kafka topic: {}", topic);
        var kafkaHelper = testContext.get("kafkaHelper", KafkaHelper.class);
        String payload = testContext.get("messagePayload", String.class);
        kafkaHelper.publish(topic, payload);
    }
```

**Validation / Assertion:**
```java
    @Then("validate response contains field {string} with value {string}")
    public void validateResponseField(String jsonPath, String expectedValue) {
        log.info("Validating response field '{}' equals: {}", jsonPath, expectedValue);
        var response = testContext.get("response", Response.class);
        String actual = response.jsonPath().getString(jsonPath);
        assertThat("Field " + jsonPath + " should match",
            actual, equalTo(expectedValue));
    }
```

**State Management:**
```java
    @Then("save response field {string} as {string}")
    public void saveResponseField(String jsonPath, String stateKey) {
        log.info("Saving response field '{}' as state key: {}", jsonPath, stateKey);
        var response = testContext.get("response", Response.class);
        String value = response.jsonPath().getString(jsonPath);
        testContext.set(stateKey, value);
        log.info("Saved {} = {}", stateKey, value);
    }
```

### DataTable Handling

Steps that receive a DataTable from Gherkin:

```java
    @Given("the following configuration:")
    public void setConfiguration(io.cucumber.datatable.DataTable dataTable) {
        log.info("Setting configuration from data table");
        List<Map<String, String>> rows = dataTable.asMaps(String.class, String.class);
        for (Map<String, String> row : rows) {
            testContext.set(row.get("key"), row.get("value"));
            log.info("Config: {} = {}", row.get("key"), row.get("value"));
        }
    }
```

## Compilation Checks (Conceptual)

Before returning code, verify:
1. All imports are resolvable (don't import classes that don't exist in the framework)
2. All `testContext.get()` calls specify the expected type
3. No raw types (always parameterize generics)
4. No unused imports
5. Method names don't collide with existing methods in the target class
6. Annotation patterns don't collide with existing patterns in the repo

## Output

Return a map of file_path → generated source code. Each entry is a complete,
compilable Java file ready to be written to disk.

For add-steps mode, return the full updated class (existing code + new methods).
Mark new code with `// NEW` comment on the method-level Javadoc.
