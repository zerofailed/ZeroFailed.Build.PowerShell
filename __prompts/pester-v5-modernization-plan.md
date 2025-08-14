# Pester v5 Modernization Plan for ZeroFailed.Build.PowerShell

## Current State Analysis

### Repository Structure
- **Current branch**: `feature/pester-v5-support`
- **Module location**: `/workspaces/ZeroFailed.Build.PowerShell/module/`
- **Key files**:
  - `tasks/test.tasks.ps1` - Contains Pester execution tasks
  - `tasks/test.properties.ps1` - Contains configuration properties
  - `ZeroFailed.Build.PowerShell.module.tests.ps1` - Module validation tests

### Current Pester Implementation Issues
1. **Uses deprecated v4-style syntax**: Current `Invoke-Pester` call uses legacy parameters:
   ```powershell
   $results = Invoke-Pester -Path $PesterTestsDir `
                            -OutputFormat $PesterOutputFormat `
                            -OutputFile $PesterOutputFilePath `
                            -PassThru `
                            -Show $PesterShowOptions
   ```

2. **Missing modern Pester v5 features**:
   - No code coverage support
   - No configuration object approach
   - Limited output format options
   - No filtering capabilities (tags, etc.)
   - No parallel execution support

3. **Current properties** (in `test.properties.ps1`):
   ```powershell
   $SkipPesterTests = $false
   $PesterVersion = "5.7.1"
   $PesterTestsDir = $null
   $PesterOutputFormat = "NUnitXml"
   $PesterOutputFilePath = "PesterTestResults.xml"
   $PesterShowOptions = @("Summary","Fails")
   ```

## Implementation Plan

### Phase 1: Migrate to Configuration Objects
**Objective**: Replace deprecated parameter syntax with modern `New-PesterConfiguration()` approach

**Tasks**:
1. Update `RunPesterTests` task in `test.tasks.ps1`:
   - Replace `Invoke-Pester` legacy parameters with configuration object
   - Map existing properties to new config structure
   - Maintain backward compatibility

**Implementation approach**:
```powershell
$config = New-PesterConfiguration()
$config.Run.Path = $PesterTestsDir
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = $PesterOutputFormat
$config.TestResult.OutputPath = $PesterOutputFilePath
$config.Output.Verbosity = 'Detailed'  # Based on $PesterShowOptions
$results = Invoke-Pester -Configuration $config
```

### Phase 2: Enable Code Coverage
**Objective**: Add comprehensive code coverage support

**New properties to add**:
```powershell
# Synopsis: When true, code coverage will be enabled for Pester tests.
$PesterCodeCoverageEnabled = $false

# Synopsis: The path(s) to analyze for code coverage. Defaults to the module functions directory.
$PesterCodeCoveragePath = @()

# Synopsis: The output format for code coverage reports.
$PesterCodeCoverageOutputFormat = "JaCoCo"

# Synopsis: The file path for the code coverage report.
$PesterCodeCoverageOutputPath = "CodeCoverage.xml"

# Synopsis: The minimum code coverage percentage required to pass.
$PesterCodeCoverageThreshold = 0
```

**Implementation**:
- Add coverage configuration to the config object
- Integrate with existing test results handling
- Support multiple coverage output formats

### Phase 3: Enhanced Configurability
**Objective**: Add modern Pester v5 filtering and execution options

**New properties**:
```powershell
# Synopsis: Tags to include when running Pester tests.
$PesterTagFilter = @()

# Synopsis: Tags to exclude when running Pester tests.
$PesterExcludeTagFilter = @()

# Synopsis: Additional output formats for test results (array of formats).
$PesterAdditionalOutputFormats = @()

# Synopsis: Additional output paths corresponding to additional formats.
$PesterAdditionalOutputPaths = @()

# Synopsis: The verbosity level for Pester output.
$PesterVerbosity = "Normal"

# Synopsis: When true, enables parallel test execution.
$PesterParallelEnabled = $false
```

### Phase 4: Testing & Validation
**Objective**: Ensure all functionality works correctly

**Tasks**:
1. Create comprehensive tests for new functionality:
   - `test.tasks.Tests.ps1` - Test the task behavior
   - Test all property combinations
   - Validate configuration object creation
   - Test error handling

2. Ensure existing tests pass:
   - Run module validation tests
   - Verify backward compatibility
   - Test default behavior unchanged

**Test scenarios**:
- Default configuration (no breaking changes)
- Code coverage enabled/disabled
- Multiple output formats
- Tag filtering
- Error conditions (invalid paths, formats)

### Phase 5: Documentation & Polish
**Objective**: Complete implementation with proper documentation

**Tasks**:
1. Add Synopsis comments for all new properties (following existing pattern)
2. Update task comments to reflect new capabilities
3. Ensure consistent naming conventions
4. Validate ZeroFailed extension principles compliance

## Technical Considerations

### Backward Compatibility
- **No breaking changes** to existing property names
- Default behavior must remain unchanged
- Existing configurations should work without modification

### ZeroFailed Compliance
- All properties must have Synopsis comments
- Follow existing naming patterns
- Maintain task structure consistency
- Support extension configurability principles

### Modern Pester v5 Features to Leverage
1. **Configuration objects**: More flexible and extensible
2. **Discovery/Run separation**: Better performance and reliability  
3. **Improved mocking**: Better scoping and debugging
4. **Code coverage**: Built-in coverage analysis
5. **Parallel execution**: Faster test runs
6. **Advanced filtering**: Tag-based test selection

## Files to Modify

### Primary Changes
1. **`module/tasks/test.properties.ps1`**:
   - Add new properties with Synopsis comments
   - Maintain existing properties for compatibility

2. **`module/tasks/test.tasks.ps1`**:
   - Update `RunPesterTests` task implementation
   - Replace legacy `Invoke-Pester` syntax
   - Add configuration object building logic

### New Files
3. **`module/tasks/test.tasks.Tests.ps1`**:
   - Comprehensive tests for task functionality
   - Validate all new properties and configurations

## Success Criteria
1. All existing tests pass without modification
2. New Pester v5 features work as expected
3. Code coverage can be enabled and configured
4. Multiple output formats supported
5. Tag filtering works correctly
6. No breaking changes to existing functionality
7. All new properties have proper Synopsis comments
8. Implementation follows ZeroFailed extension patterns

## Dependencies
- Pester 5.7.1+ (already specified)
- PowerShell Core 7.0+ (already required)
- ZeroFailed framework (already integrated)

## Migration Benefits
- **Modern approach**: Uses current Pester v5 best practices
- **Enhanced testing**: Code coverage and advanced filtering
- **Better maintainability**: Configuration objects are more flexible
- **Future-proof**: Ready for Pester v6 migration path
- **Improved CI/CD**: Better reporting and coverage integration