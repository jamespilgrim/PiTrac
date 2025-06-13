# Camera Bounded Context - Unit Tests
# Using Boost Test Framework with xUnit Arrange-Act-Assert pattern

# Configure Boost detection
set(Boost_USE_STATIC_LIBS OFF)
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME OFF)

# Debug information
message(STATUS "Looking for Boost Test framework...")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
message(STATUS "Boost_ROOT: ${Boost_ROOT}")
message(STATUS "BOOST_ROOT: $ENV{BOOST_ROOT}")

# Try different Boost component names based on platform and version
if(WIN32)
    # On Windows, try different naming conventions
    find_package(Boost QUIET COMPONENTS unit_test_framework)
    if(NOT Boost_unit_test_framework_FOUND)
        message(STATUS "unit_test_framework not found, trying 'test'")
        find_package(Boost QUIET COMPONENTS test)
        if(NOT Boost_test_FOUND)
            message(STATUS "test not found, trying 'test_exec_monitor'")
            find_package(Boost QUIET COMPONENTS test_exec_monitor)
            if(NOT Boost_test_exec_monitor_FOUND)
                message(STATUS "No test libraries found, falling back to header-only")
                # Try header-only approach as fallback
                find_package(Boost REQUIRED)
                set(BOOST_TEST_HEADER_ONLY TRUE)
            endif()
        endif()
    endif()
else()
    # On Unix systems, standard naming should work
    find_package(Boost REQUIRED COMPONENTS unit_test_framework)
endif()

# Debug what we found
message(STATUS "Boost_FOUND: ${Boost_FOUND}")
message(STATUS "Boost_VERSION: ${Boost_VERSION}")
message(STATUS "Boost_INCLUDE_DIRS: ${Boost_INCLUDE_DIRS}")
message(STATUS "Boost_LIBRARIES: ${Boost_LIBRARIES}")
message(STATUS "BOOST_TEST_HEADER_ONLY: ${BOOST_TEST_HEADER_ONLY}")

# Create the test executable target
add_executable(camera_tests
    test_main.cpp
    domain/test_camera_domain.cpp
    domain/test_advanced_domain.cpp
    infrastructure/test_platform_selection.cpp
)

# Configure linking based on what we found
if(BOOST_TEST_HEADER_ONLY)
    # Header-only mode - no linking required
    target_compile_definitions(camera_tests 
        PRIVATE 
        BOOST_TEST_HEADER_ONLY=1
    )
    target_include_directories(camera_tests 
        PRIVATE 
        ${Boost_INCLUDE_DIRS}
    )
else()
    # Linked library mode
    if(TARGET Boost::unit_test_framework)
        target_link_libraries(camera_tests PRIVATE Boost::unit_test_framework)
        target_compile_definitions(camera_tests PRIVATE BOOST_TEST_DYN_LINK)
    elseif(TARGET Boost::test)
        target_link_libraries(camera_tests PRIVATE Boost::test)
        target_compile_definitions(camera_tests PRIVATE BOOST_TEST_DYN_LINK)
    elseif(TARGET Boost::test_exec_monitor)
        target_link_libraries(camera_tests PRIVATE Boost::test_exec_monitor)
        target_compile_definitions(camera_tests PRIVATE BOOST_TEST_DYN_LINK)
    else()
        # Fallback to old-style variables
        target_link_libraries(camera_tests PRIVATE ${Boost_LIBRARIES})
        target_include_directories(camera_tests PRIVATE ${Boost_INCLUDE_DIRS})
        target_compile_definitions(camera_tests PRIVATE BOOST_TEST_DYN_LINK)
    endif()
endif()

# Include paths for testing
target_include_directories(camera_tests 
    PRIVATE 
    ${CMAKE_CURRENT_SOURCE_DIR}/..  # Camera bounded context root
    ${CMAKE_CURRENT_SOURCE_DIR}     # Test directory
)

# Enable testing for this directory
enable_testing()

# Register the test with CTest
add_test(
    NAME camera_unit_tests
    COMMAND camera_tests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

# Set test properties for better output
set_tests_properties(camera_unit_tests 
    PROPERTIES
    TIMEOUT 30
    LABELS "unit;camera"
)

# Create test groups for selective running
add_test(
    NAME camera_domain_tests
    COMMAND camera_tests --run_test=DomainTests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

add_test(
    NAME camera_infrastructure_tests  
    COMMAND camera_tests --run_test=InfrastructureTests
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
)

# Platform-specific conditional tests
if(UNIX)
    add_test(
        NAME camera_unix_tests
        COMMAND camera_tests --run_test=UnixTests
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
elseif(WIN32)
    add_test(
        NAME camera_windows_tests
        COMMAND camera_tests --run_test=WindowsTests  
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
endif()
