# Step Definition Class Template

## Full Template — New Class

Copy this template when `mode = "new-class"`. Replace all `{placeholders}`.

```java
package com.theocc.raf.automation.stepdefs.{domain};

// === Cucumber ===
import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;
// import io.cucumber.datatable.DataTable; // Only if steps use data tables

// === Logging ===
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

// === Spring ===
import org.springframework.stereotype.Component;

// === Framework (include ONLY what's needed) ===
import com.theocc.raf.automation.context.TestContext;
// import com.theocc.raf.automation.rest.RestClient;        // For API steps
// import com.theocc.raf.automation.db.DatabaseHelper;      // For DB steps
// import com.theocc.raf.automation.kafka.KafkaHelper;      // For Kafka steps
// import com.theocc.raf.automation.ui.PageObjectFactory;   // For UI steps
// import com.theocc.raf.automation.config.PropertyResolver; // For property loading
// import com.theocc.raf.automation.state.StateManager;     // For state operations

// === Assertions (for Then/validation steps) ===
// import static org.hamcrest.MatcherAssert.assertThat;
// import static org.hamcrest.Matchers.*;
// import static org.junit.Assert.*;

/**
 * Step definitions for {one-line description}.
 *
 * <p>{Extended description of what domain/feature area these steps cover.}
 *
 * <p>Consumed by feature files in:
 * <ul>
 *   <li>{module}-features/src/test/resources/features/{subdirectory}/</li>
 * </ul>
 *
 * @author OCC RNS Automation
 * @since {YYYY-MM-DD}
 */
@Component
public class {ClassName} {

    private static final Logger log = LoggerFactory.getLogger({ClassName}.class);

    private final TestContext testContext;
    // private final RestClient restClient;       // Uncomment if needed
    // private final DatabaseHelper dbHelper;     // Uncomment if needed
    // private final KafkaHelper kafkaHelper;     // Uncomment if needed
    // private final PageObjectFactory pageFactory; // Uncomment if needed

    /**
     * Constructor — Spring injects all dependencies.
     *
     * @param testContext scenario-scoped state store
     */
    public {ClassName}(TestContext testContext) {
        this.testContext = testContext;
    }

    // =========================================================================
    // GIVEN — Precondition / Setup Steps
    // =========================================================================

    // {Given steps go here}

    // =========================================================================
    // WHEN — Action Steps
    // =========================================================================

    // {When steps go here}

    // =========================================================================
    // THEN — Validation / Assertion Steps
    // =========================================================================

    // {Then steps go here}
}
```

---

## Method Templates by Category

### API Setup

```java
    /**
     * Initialize REST client from a named properties file.
     *
     * @param propertiesFile name of the properties file (without .properties extension)
     */
    @Given("rest client is created with properties file {string}")
    public void createRestClient(String propertiesFile) {
        log.info("Creating REST client with properties: {}", propertiesFile);
        restClient.initialize(propertiesFile);
        testContext.set("restClient", restClient);
    }
```

### API Action

```java
    /**
     * Send an HTTP request to the specified endpoint.
     *
     * @param method HTTP method (GET, POST, PUT, DELETE)
     * @param endpoint API endpoint path
     */
    @When("{word} request is invoked to endpoint {string}")
    public void invokeRequest(String method, String endpoint) {
        log.info("Invoking {} request to: {}", method, endpoint);
        var client = testContext.get("restClient", RestClient.class);
        var response = client.invoke(method, endpoint);
        testContext.set("response", response);
        testContext.set("statusCode", response.getStatusCode());
        log.info("Response status: {}", response.getStatusCode());
    }
```

### UI Navigation

```java
    /**
     * Navigate the browser to the specified page.
     *
     * @param pageName logical page name mapped in configuration
     */
    @Given("user navigates to {string}")
    public void navigateToPage(String pageName) {
        log.info("Navigating to page: {}", pageName);
        var page = pageFactory.createPage(pageName);
        page.navigate();
        testContext.set("currentPage", page);
    }
```

### UI Interaction

```java
    /**
     * Click on a UI element identified by its locator key.
     *
     * @param locator element locator key from the page object
     */
    @When("user clicks on element {string}")
    public void clickOnElement(String locator) {
        log.info("Clicking element: {}", locator);
        var page = testContext.get("currentPage", BasePage.class);
        page.clickElement(locator);
    }
```

### Validation

```java
    /**
     * Assert that a JSON path in the response equals the expected value.
     *
     * @param jsonPath JSON path expression
     * @param expected expected value
     */
    @Then("validate jsonPath {string} equals {string}")
    public void validateJsonPath(String jsonPath, String expected) {
        log.info("Validating jsonPath '{}' equals '{}'", jsonPath, expected);
        var response = testContext.get("response", Response.class);
        String actual = response.jsonPath().getString(jsonPath);
        assertThat(String.format("jsonPath '%s' should equal '%s'", jsonPath, expected),
            actual, equalTo(expected));
    }
```

### State Storage

```java
    /**
     * Extract a value from the response and store it in the test context.
     *
     * @param jsonPath JSON path to extract
     * @param stateKey key to store the value under
     */
    @Then("save CONTEXT value from jsonPath {string} as {string}")
    public void saveFromJsonPath(String jsonPath, String stateKey) {
        log.info("Saving jsonPath '{}' as state key '{}'", jsonPath, stateKey);
        var response = testContext.get("response", Response.class);
        String value = response.jsonPath().getString(jsonPath);
        testContext.set(stateKey, value);
        log.info("Stored: {} = {}", stateKey, value);
    }
```

### Database Query

```java
    /**
     * Execute a named SQL query against the database.
     *
     * @param queryKey key identifying the query (from properties or inline)
     */
    @When("query is executed with {string}")
    public void executeQuery(String queryKey) {
        log.info("Executing database query: {}", queryKey);
        var result = dbHelper.executeQuery(queryKey);
        testContext.set("queryResult", result);
        log.info("Query returned {} rows", result.size());
    }
```

### Kafka

```java
    /**
     * Consume the next message from a Kafka topic.
     *
     * @param topic Kafka topic name
     */
    @When("message is consumed from topic {string}")
    public void consumeFromTopic(String topic) {
        log.info("Consuming message from topic: {}", topic);
        var consumer = testContext.get("kafkaConsumer", KafkaHelper.class);
        String message = consumer.consume(topic);
        testContext.set("kafkaMessage", message);
        log.info("Consumed message length: {}", message.length());
    }
```

---

## Naming Convention Quick Reference

| Pattern | Class Name Example |
|---------|-------------------|
| Notification UI actions | `NotificationUISteps.java` |
| Notification API calls | `NotificationApiSteps.java` |
| Notification validation | `NotificationValidationSteps.java` |
| Margin calculation | `MarginCalculationSteps.java` |
| Collateral management DB | `CollateralDbSteps.java` |
| Common REST setup | `RestClientSetupSteps.java` |
| Common state management | `StateManagementSteps.java` |
| Kafka messaging | `KafkaMessagingSteps.java` |
