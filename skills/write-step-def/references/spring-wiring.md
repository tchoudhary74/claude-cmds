# Spring Wiring Reference — OCC RNS Step Definitions

## Overview

All step definition classes are Spring-managed beans. The Cucumber-Spring
integration handles instantiation and dependency injection. Understanding
the wiring model is critical — incorrect wiring causes runtime failures
that are hard to debug.

---

## TestContext — The State Sharing Mechanism

`TestContext` is a scenario-scoped bean that acts as a key-value store
shared across all step definition classes within a single scenario execution.

```java
// Injected via constructor
private final TestContext testContext;

// Store a value
testContext.set("responseBody", response.body().asString());

// Retrieve a value (type-safe)
String body = testContext.get("responseBody", String.class);

// Check if key exists
boolean hasResponse = testContext.containsKey("responseBody");
```

### Key Naming Conventions

Use descriptive, domain-prefixed keys:
```
restClient          — the initialized REST client
response            — latest HTTP response
statusCode          — latest response status code
dbConnection        — active database connection
queryResult         — latest query result set
kafkaConsumer       — initialized Kafka consumer
kafkaMessage        — latest consumed message
currentPage         — current Selenium Page Object
messagePayload      — message body for Kafka publish
```

For dynamic keys (multiple values of same type), use suffixes:
```
response.margin     — response from margin API
response.clearing   — response from clearing API
queryResult.trade   — result of trade query
queryResult.account — result of account query
```

---

## Constructor Injection Pattern (REQUIRED)

All dependencies must be injected via constructor. This is the team standard.

```java
@Component
public class NotificationSteps {

    private static final Logger log = LoggerFactory.getLogger(NotificationSteps.class);

    private final TestContext testContext;
    private final RestClient restClient;
    private final DatabaseHelper databaseHelper;

    // Constructor injection — Spring auto-resolves all parameters
    public NotificationSteps(
            TestContext testContext,
            RestClient restClient,
            DatabaseHelper databaseHelper) {
        this.testContext = testContext;
        this.restClient = restClient;
        this.databaseHelper = databaseHelper;
    }
}
```

### DO NOT use field injection:

```java
// ❌ WRONG — will be rejected in PR review
@Autowired
private TestContext testContext;

@Autowired
private RestClient restClient;
```

---

## Available Injectable Beans

These beans are registered in the Spring context and available for injection:

| Bean | Class | Purpose |
|------|-------|---------|
| TestContext | `com.theocc.raf.automation.context.TestContext` | Scenario-scoped state store |
| RestClient | `com.theocc.raf.automation.rest.RestClient` | HTTP client wrapper |
| DatabaseHelper | `com.theocc.raf.automation.db.DatabaseHelper` | JDBC query executor |
| KafkaHelper | `com.theocc.raf.automation.kafka.KafkaHelper` | Kafka producer/consumer |
| PropertyResolver | `com.theocc.raf.automation.config.PropertyResolver` | Property file reader |
| WebDriverManager | `com.theocc.raf.automation.ui.WebDriverManager` | Selenium driver lifecycle |
| PageObjectFactory | `com.theocc.raf.automation.ui.PageObjectFactory` | Page Object instantiation |
| AssertionHelper | `com.theocc.raf.automation.assertion.AssertionHelper` | Custom assertion utilities |
| StateManager | `com.theocc.raf.automation.state.StateManager` | Global/Local state resolution |
| ReportHelper | `com.theocc.raf.automation.report.ReportHelper` | Extent/Allure report hooks |

**Only inject what you need.** Unused injections waste resources and make
the class harder to understand.

---

## Scenario Lifecycle

Understanding the lifecycle prevents common bugs:

```
1. Spring creates step class instances (once per scenario)
2. @Before hooks run (setup)
3. Given steps execute (preconditions)
4. When steps execute (actions)
5. Then steps execute (assertions)
6. @After hooks run (cleanup)
7. TestContext is cleared (scenario-scoped — all state gone)
```

**Implication**: You cannot share state between scenarios via TestContext.
Each scenario starts with a clean TestContext. If you need cross-scenario
state, use the StateManager's GLOBAL scope (but prefer isolated scenarios).

---

## Property File Resolution

Step definitions that reference property files:

```java
@Given("rest client is created with properties file {string}")
public void createRestClient(String propertiesFile) {
    // PropertyResolver looks in: {module}-features/src/test/resources/conf/
    Properties props = propertyResolver.load(propertiesFile);
    RestClient client = new RestClient(props);
    testContext.set("restClient", client);
}
```

**Property file naming**: The {string} parameter is the filename WITHOUT
the `.properties` extension. The framework appends it.

Example: `"margin-api"` → resolves to `conf/margin-api.properties`

---

## Page Object Integration (UI Steps)

For UI step definitions, use the PageObjectFactory:

```java
@Component
public class NotificationUISteps {

    private final TestContext testContext;
    private final PageObjectFactory pageFactory;

    public NotificationUISteps(TestContext testContext, PageObjectFactory pageFactory) {
        this.testContext = testContext;
        this.pageFactory = pageFactory;
    }

    @Given("user is on the {string} page")
    public void navigateToPage(String pageName) {
        BasePage page = pageFactory.createPage(pageName);
        page.navigate();
        testContext.set("currentPage", page);
    }

    @When("user clicks on element {string}")
    public void clickElement(String locator) {
        BasePage page = testContext.get("currentPage", BasePage.class);
        page.clickElement(locator);
    }
}
```

**Never instantiate WebDriver directly in step definitions.**
Always go through WebDriverManager or PageObjectFactory.

---

## Error Handling Guidelines

```java
// ✅ CORRECT — Let exceptions propagate for Cucumber reporting
@Then("validate response status is {int}")
public void validateStatus(int expectedStatus) {
    int actual = testContext.get("statusCode", Integer.class);
    assertThat("HTTP status should match", actual, equalTo(expectedStatus));
    // AssertionError propagates → Cucumber marks step as FAILED
}

// ❌ WRONG — Swallowing exceptions hides failures
@Then("validate response status is {int}")
public void validateStatus(int expectedStatus) {
    try {
        int actual = testContext.get("statusCode", Integer.class);
        assertThat(actual, equalTo(expectedStatus));
    } catch (Exception e) {
        log.error("Validation failed", e); // HIDDEN! Test passes incorrectly
    }
}

// ✅ ACCEPTABLE — Catch to add context, then rethrow
@Then("validate response field {string} equals {string}")
public void validateField(String path, String expected) {
    try {
        String actual = testContext.get("response", Response.class)
            .jsonPath().getString(path);
        assertThat(actual, equalTo(expected));
    } catch (AssertionError e) {
        throw new AssertionError(
            String.format("Field '%s': expected '%s' but got '%s'", path, expected,
                testContext.get("response", Response.class).jsonPath().getString(path)), e);
    }
}
```
