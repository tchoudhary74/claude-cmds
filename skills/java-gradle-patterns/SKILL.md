# Java & Gradle Patterns

## Gradle build.gradle.kts Best Practices

### Basic Structure
```kotlin
plugins {
    id("java")
    id("org.springframework.boot") version "3.2.0"
    id("io.spring.dependency-management") version "1.1.4"
    id("jacoco")
}

group = "com.example"
version = "1.0.0"

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

repositories {
    mavenCentral()
}

dependencies {
    // Implementation - internal use, not exposed to consumers
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    // API - exposed to consumers (for libraries)
    // api("com.google.guava:guava:32.1.3-jre")

    // CompileOnly - needed at compile time, not runtime
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")

    // RuntimeOnly - needed at runtime, not compile time
    runtimeOnly("org.postgresql:postgresql")

    // Test dependencies
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
    testImplementation("org.mockito:mockito-core:5.7.0")
    testImplementation("org.mockito:mockito-junit-jupiter:5.7.0")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required.set(true)
        html.required.set(true)
    }
}
```

---

## Multi-Module Project Structure

```
my-project/
├── build.gradle.kts           # Root build file
├── settings.gradle.kts        # Module definitions
├── gradle.properties          # Shared properties
├── app/                       # Application module
│   ├── build.gradle.kts
│   └── src/
├── core/                      # Core business logic
│   ├── build.gradle.kts
│   └── src/
├── common/                    # Shared utilities
│   ├── build.gradle.kts
│   └── src/
└── infrastructure/            # External integrations
    ├── build.gradle.kts
    └── src/
```

### settings.gradle.kts
```kotlin
rootProject.name = "my-project"

include(":app")
include(":core")
include(":common")
include(":infrastructure")
```

### Root build.gradle.kts
```kotlin
plugins {
    id("java")
    id("org.springframework.boot") version "3.2.0" apply false
    id("io.spring.dependency-management") version "1.1.4" apply false
}

allprojects {
    group = "com.example"
    version = "1.0.0"

    repositories {
        mavenCentral()
    }
}

subprojects {
    apply(plugin = "java")
    apply(plugin = "io.spring.dependency-management")

    java {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    dependencies {
        testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
        testImplementation("org.mockito:mockito-core:5.7.0")
    }

    tasks.withType<Test> {
        useJUnitPlatform()
    }
}
```

### App Module build.gradle.kts
```kotlin
plugins {
    id("org.springframework.boot")
}

dependencies {
    implementation(project(":core"))
    implementation(project(":infrastructure"))
    implementation("org.springframework.boot:spring-boot-starter-web")
}
```

---

## Dependency Management

| Scope | Description | Use Case |
|-------|-------------|----------|
| `implementation` | Internal dependency | Most dependencies |
| `api` | Exposed to consumers | Library modules |
| `compileOnly` | Compile-time only | Lombok, annotations |
| `runtimeOnly` | Runtime only | JDBC drivers, logging impl |
| `testImplementation` | Test compile + runtime | JUnit, Mockito |
| `annotationProcessor` | Annotation processing | Lombok, MapStruct |

### Version Catalogs (gradle/libs.versions.toml)
```toml
[versions]
spring-boot = "3.2.0"
junit = "5.10.0"
mockito = "5.7.0"

[libraries]
spring-boot-starter-web = { module = "org.springframework.boot:spring-boot-starter-web", version.ref = "spring-boot" }
junit-jupiter = { module = "org.junit.jupiter:junit-jupiter", version.ref = "junit" }
mockito-core = { module = "org.mockito:mockito-core", version.ref = "mockito" }

[bundles]
testing = ["junit-jupiter", "mockito-core"]

[plugins]
spring-boot = { id = "org.springframework.boot", version.ref = "spring-boot" }
```

Usage:
```kotlin
dependencies {
    implementation(libs.spring.boot.starter.web)
    testImplementation(libs.bundles.testing)
}
```

---

## Spring Boot Patterns

### Controller Layer
```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping
    public ResponseEntity<List<UserResponse>> getAllUsers() {
        return ResponseEntity.ok(userService.findAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUserById(@PathVariable Long id) {
        return userService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<UserResponse> createUser(
            @Valid @RequestBody CreateUserRequest request) {
        UserResponse created = userService.create(request);
        URI location = URI.create("/api/v1/users/" + created.getId());
        return ResponseEntity.created(location).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return userService.update(id, request)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        if (userService.delete(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}
```

### Service Layer
```java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;

    public List<UserResponse> findAll() {
        return userRepository.findAll().stream()
                .map(userMapper::toResponse)
                .toList();
    }

    public Optional<UserResponse> findById(Long id) {
        return userRepository.findById(id)
                .map(userMapper::toResponse);
    }

    @Transactional
    public UserResponse create(CreateUserRequest request) {
        User user = userMapper.toEntity(request);
        User saved = userRepository.save(user);
        return userMapper.toResponse(saved);
    }

    @Transactional
    public Optional<UserResponse> update(Long id, UpdateUserRequest request) {
        return userRepository.findById(id)
                .map(user -> {
                    userMapper.updateEntity(user, request);
                    return userMapper.toResponse(userRepository.save(user));
                });
    }

    @Transactional
    public boolean delete(Long id) {
        if (userRepository.existsById(id)) {
            userRepository.deleteById(id);
            return true;
        }
        return false;
    }
}
```

### Repository Layer
```java
@Repository
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.status = :status")
    List<User> findByStatus(@Param("status") UserStatus status);

    @Query("SELECT u FROM User u WHERE u.createdAt >= :since")
    Page<User> findRecentUsers(@Param("since") LocalDateTime since, Pageable pageable);

    boolean existsByEmail(String email);
}
```

### Entity
```java
@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String email;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserStatus status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

---

## Exception Handling

### Global Exception Handler
```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleNotFound(ResourceNotFoundException ex) {
        log.warn("Resource not found: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(ErrorResponse.of(ex.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidation(
            MethodArgumentNotValidException ex) {
        List<String> errors = ex.getBindingResult().getFieldErrors().stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .toList();
        return ResponseEntity.badRequest()
                .body(ErrorResponse.of("Validation failed", errors));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ErrorResponse> handleBusinessException(BusinessException ex) {
        log.warn("Business error: {}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
                .body(ErrorResponse.of(ex.getMessage()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneral(Exception ex) {
        log.error("Unexpected error", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(ErrorResponse.of("An unexpected error occurred"));
    }
}

@Getter
@AllArgsConstructor(staticName = "of")
public class ErrorResponse {
    private final String message;
    private final List<String> details;
    private final LocalDateTime timestamp = LocalDateTime.now();

    public static ErrorResponse of(String message) {
        return new ErrorResponse(message, List.of());
    }
}
```

### Custom Exceptions
```java
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String resource, Long id) {
        super(resource + " not found with id: " + id);
    }
}

public class BusinessException extends RuntimeException {
    public BusinessException(String message) {
        super(message);
    }
}
```

---

## Logging with SLF4J/Logback

### logback-spring.xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <include resource="org/springframework/boot/logging/logback/defaults.xml"/>

    <property name="LOG_PATH" value="${LOG_PATH:-logs}"/>
    <property name="LOG_FILE" value="${LOG_FILE:-application}"/>

    <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} %5level [%15.15thread] %-40.40logger{39} : %msg%n</pattern>
        </encoder>
    </appender>

    <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>${LOG_PATH}/${LOG_FILE}.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
            <fileNamePattern>${LOG_PATH}/${LOG_FILE}.%d{yyyy-MM-dd}.gz</fileNamePattern>
            <maxHistory>30</maxHistory>
            <totalSizeCap>1GB</totalSizeCap>
        </rollingPolicy>
        <encoder>
            <pattern>%d{yyyy-MM-dd HH:mm:ss.SSS} %5level [%15.15thread] %-40.40logger{39} : %msg%n</pattern>
        </encoder>
    </appender>

    <logger name="com.example" level="DEBUG"/>
    <logger name="org.springframework" level="INFO"/>
    <logger name="org.hibernate.SQL" level="DEBUG"/>

    <root level="INFO">
        <appender-ref ref="CONSOLE"/>
        <appender-ref ref="FILE"/>
    </root>
</configuration>
```

### Logging Usage
```java
@Slf4j
@Service
public class UserService {

    public void processUser(Long userId) {
        log.info("Processing user with id: {}", userId);
        try {
            // processing logic
            log.debug("User processed successfully: {}", userId);
        } catch (Exception e) {
            log.error("Failed to process user {}: {}", userId, e.getMessage(), e);
            throw e;
        }
    }
}
```

---

## Testing with JUnit 5 + Mockito

### Unit Test
```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserMapper userMapper;

    @InjectMocks
    private UserService userService;

    @Test
    @DisplayName("Should return user when found by id")
    void findById_WhenUserExists_ReturnsUser() {
        // Given
        Long userId = 1L;
        User user = User.builder().id(userId).name("John").build();
        UserResponse response = new UserResponse(userId, "John");

        when(userRepository.findById(userId)).thenReturn(Optional.of(user));
        when(userMapper.toResponse(user)).thenReturn(response);

        // When
        Optional<UserResponse> result = userService.findById(userId);

        // Then
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("John");
        verify(userRepository).findById(userId);
    }

    @Test
    @DisplayName("Should return empty when user not found")
    void findById_WhenUserNotFound_ReturnsEmpty() {
        // Given
        Long userId = 999L;
        when(userRepository.findById(userId)).thenReturn(Optional.empty());

        // When
        Optional<UserResponse> result = userService.findById(userId);

        // Then
        assertThat(result).isEmpty();
        verify(userMapper, never()).toResponse(any());
    }
}
```

### Integration Test
```java
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class UserControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("Should create user and return 201")
    void createUser_WithValidRequest_ReturnsCreated() throws Exception {
        // Given
        CreateUserRequest request = new CreateUserRequest("John", "john@example.com");

        // When/Then
        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.name").value("John"))
                .andExpect(jsonPath("$.email").value("john@example.com"));

        assertThat(userRepository.findByEmail("john@example.com")).isPresent();
    }

    @Test
    @DisplayName("Should return 400 for invalid request")
    void createUser_WithInvalidRequest_ReturnsBadRequest() throws Exception {
        // Given
        CreateUserRequest request = new CreateUserRequest("", "invalid-email");

        // When/Then
        mockMvc.perform(post("/api/v1/users")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Validation failed"));
    }
}
```

---

## Gradle Task Optimization

### Build Caching
```kotlin
// gradle.properties
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.daemon=true
org.gradle.jvmargs=-Xmx2g -XX:+HeapDumpOnOutOfMemoryError

// Enable configuration cache (Gradle 8+)
org.gradle.configuration-cache=true
```

### Custom Tasks
```kotlin
tasks.register("generateBuildInfo") {
    val outputDir = layout.buildDirectory.dir("generated/build-info")
    outputs.dir(outputDir)

    doLast {
        outputDir.get().asFile.mkdirs()
        file("${outputDir.get()}/build-info.properties").writeText("""
            version=${project.version}
            timestamp=${java.time.Instant.now()}
            git.commit=${providers.exec { commandLine("git", "rev-parse", "HEAD") }.standardOutput.asText.get().trim()}
        """.trimIndent())
    }
}

tasks.processResources {
    dependsOn("generateBuildInfo")
    from(layout.buildDirectory.dir("generated/build-info"))
}
```

### Common Commands
```bash
# Build
./gradlew build
./gradlew build -x test              # Skip tests
./gradlew clean build --no-build-cache

# Testing
./gradlew test
./gradlew test --tests "UserServiceTest"
./gradlew test --tests "*IntegrationTest"
./gradlew jacocoTestReport

# Dependencies
./gradlew dependencies
./gradlew dependencyUpdates          # Check for updates (requires plugin)

# Multi-module
./gradlew :app:build
./gradlew :core:test
```
