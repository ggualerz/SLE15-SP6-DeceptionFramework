#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to check if deception framework is available
check_deception_framework() {
    print_header "Checking Deception Framework Availability"
    
    if [[ -d "/proc/deception" ]]; then
        print_success "Deception framework directory exists"
        if [[ -f "/proc/deception/rules" ]]; then
            print_success "Rules file is accessible"
            return 0
        else
            print_error "Rules file not found"
            return 1
        fi
    else
        print_error "Deception framework not found"
        print_info "Make sure you're running the modified kernel"
        return 1
    fi
}

# Function to test basic uname hooking
test_uname_hooking() {
    print_header "Testing Uname Syscall Hooking"
    
    # Get original uname values
    ORIGINAL_SYSNAME=$(uname -s)
    ORIGINAL_NODENAME=$(uname -n)
    ORIGINAL_RELEASE=$(uname -r)
    ORIGINAL_MACHINE=$(uname -m)
    
    print_info "Original system name: $ORIGINAL_SYSNAME"
    print_info "Original node name: $ORIGINAL_NODENAME"
    print_info "Original release: $ORIGINAL_RELEASE"
    print_info "Original machine: $ORIGINAL_MACHINE"
    
    # Test 1: Change system name
    print_test "Changing system name to 'FakeOS'"
    echo "add:uname:$ORIGINAL_SYSNAME:FakeOS:/" > /proc/deception/rules
    
    NEW_SYSNAME=$(uname -s)
    if [[ "$NEW_SYSNAME" == "FakeOS" ]]; then
        print_success "System name successfully changed to FakeOS"
    else
        print_error "System name not changed. Expected: FakeOS, Got: $NEW_SYSNAME"
    fi
    
    # Test 2: Change node name
    print_test "Changing node name to 'FakeNode'"
    echo "add:uname:$ORIGINAL_NODENAME:FakeNode:/" > /proc/deception/rules
    
    NEW_NODENAME=$(uname -n)
    if [[ "$NEW_NODENAME" == "FakeNode" ]]; then
        print_success "Node name successfully changed to FakeNode"
    else
        print_error "Node name not changed. Expected: FakeNode, Got: $NEW_NODENAME"
    fi
    
    # Test 3: Change release
    print_test "Changing release to 'FakeRelease'"
    echo "add:uname:$ORIGINAL_RELEASE:FakeRelease:/" > /proc/deception/rules
    
    NEW_RELEASE=$(uname -r)
    if [[ "$NEW_RELEASE" == "FakeRelease" ]]; then
        print_success "Release successfully changed to FakeRelease"
    else
        print_error "Release not changed. Expected: FakeRelease, Got: $NEW_RELEASE"
    fi
    
    # Test 4: Change machine
    print_test "Changing machine to 'FakeArch'"
    echo "add:uname:$ORIGINAL_MACHINE:FakeArch:/" > /proc/deception/rules
    
    NEW_MACHINE=$(uname -m)
    if [[ "$NEW_MACHINE" == "FakeArch" ]]; then
        print_success "Machine successfully changed to FakeArch"
    else
        print_error "Machine not changed. Expected: FakeArch, Got: $NEW_MACHINE"
    fi
    
    # Test 5: Test the specific case mentioned by user
    print_test "Testing 'My totally not fake kernel' replacement"
    echo "add:uname:$ORIGINAL_SYSNAME:My totally not fake kernel:/" > /proc/deception/rules
    
    CUSTOM_SYSNAME=$(uname -s)
    if [[ "$CUSTOM_SYSNAME" == "My totally not fake kernel" ]]; then
        print_success "System name successfully changed to 'My totally not fake kernel'"
    else
        print_error "System name not changed. Expected: 'My totally not fake kernel', Got: $CUSTOM_SYSNAME"
    fi
}

# Function to test rule management
test_rule_management() {
    print_header "Testing Rule Management"
    
    # Test 1: List current rules
    print_test "Listing current rules"
    CURRENT_RULES=$(cat /proc/deception/rules 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        print_success "Rules listing works"
        print_info "Current rules:"
        echo "$CURRENT_RULES"
    else
        print_error "Failed to list rules"
    fi
    
    # Test 2: Clear all rules
    print_test "Clearing all rules"
    echo "clear" > /proc/deception/rules
    
    CLEARED_RULES=$(cat /proc/deception/rules 2>/dev/null)
    if [[ -z "$CLEARED_RULES" ]]; then
        print_success "Rules cleared successfully"
    else
        print_error "Rules not cleared properly"
    fi
    
    # Test 3: Add multiple rules
    print_test "Adding multiple rules"
    echo "add:uname:Linux:FakeOS:/" > /proc/deception/rules
    echo "add:uname:x86_64:FakeArch:/" > /proc/deception/rules
    
    MULTIPLE_RULES=$(cat /proc/deception/rules 2>/dev/null)
    if [[ -n "$MULTIPLE_RULES" ]]; then
        print_success "Multiple rules added successfully"
        print_info "Current rules:"
        echo "$MULTIPLE_RULES"
    else
        print_error "Failed to add multiple rules"
    fi
    
    # Test 4: Remove specific rule
    print_test "Removing specific rule"
    echo "remove:uname:Linux:FakeOS:/" > /proc/deception/rules
    
    REMAINING_RULES=$(cat /proc/deception/rules 2>/dev/null)
    if [[ -n "$REMAINING_RULES" ]]; then
        print_success "Rule removal works"
        print_info "Remaining rules:"
        echo "$REMAINING_RULES"
    else
        print_error "Rule removal failed"
    fi
}

# Function to test error handling
test_error_handling() {
    print_header "Testing Error Handling"
    
    # Test 1: Invalid rule format
    print_test "Testing invalid rule format"
    echo "invalid_rule" > /proc/deception/rules 2>/dev/null
    if [[ $? -ne 0 ]]; then
        print_success "Invalid rule format properly rejected"
    else
        print_error "Invalid rule format not rejected"
    fi
    
    # Test 2: Empty rule
    print_test "Testing empty rule"
    echo "" > /proc/deception/rules 2>/dev/null
    if [[ $? -ne 0 ]]; then
        print_success "Empty rule properly rejected"
    else
        print_error "Empty rule not rejected"
    fi
    
    # Test 3: Rule with special characters
    print_test "Testing rule with special characters"
    echo "add:uname:Linux:Fake\ OS:/" > /proc/deception/rules 2>/dev/null
    if [[ $? -eq 0 ]]; then
        print_success "Rule with special characters accepted"
    else
        print_error "Rule with special characters rejected"
    fi
}

# Function to test persistence
test_persistence() {
    print_header "Testing Rule Persistence"
    
    # Set a rule
    print_test "Setting a rule and checking persistence"
    echo "add:uname:Linux:PersistentOS:/" > /proc/deception/rules
    
    # Check immediate effect
    IMMEDIATE_RESULT=$(uname -s)
    if [[ "$IMMEDIATE_RESULT" == "PersistentOS" ]]; then
        print_success "Rule applied immediately"
    else
        print_error "Rule not applied immediately"
    fi
    
    # Wait a moment and check again
    sleep 1
    PERSISTENT_RESULT=$(uname -s)
    if [[ "$PERSISTENT_RESULT" == "PersistentOS" ]]; then
        print_success "Rule persists over time"
    else
        print_error "Rule does not persist"
    fi
}

# Function to test multiple processes
test_multiple_processes() {
    print_header "Testing Multiple Processes"
    
    # Set a rule
    echo "add:uname:Linux:MultiProcessOS:/" > /proc/deception/rules
    
    # Test with different processes
    print_test "Testing with bash process"
    BASH_RESULT=$(bash -c 'uname -s')
    if [[ "$BASH_RESULT" == "MultiProcessOS" ]]; then
        print_success "Bash process sees modified uname"
    else
        print_error "Bash process does not see modified uname"
    fi
    
    print_test "Testing with python process"
    PYTHON_RESULT=$(python3 -c "import os; print(os.uname().sysname)" 2>/dev/null)
    if [[ "$PYTHON_RESULT" == "MultiProcessOS" ]]; then
        print_success "Python process sees modified uname"
    else
        print_error "Python process does not see modified uname"
    fi
    
    print_test "Testing with C program"
    cat > test_uname.c << 'EOF'
#include <sys/utsname.h>
#include <stdio.h>
int main() {
    struct utsname uts;
    if (uname(&uts) == 0) {
        printf("%s\n", uts.sysname);
    }
    return 0;
}
EOF
    gcc -o test_uname test_uname.c 2>/dev/null
    if [[ $? -eq 0 ]]; then
        C_RESULT=$(./test_uname)
        if [[ "$C_RESULT" == "MultiProcessOS" ]]; then
            print_success "C program sees modified uname"
        else
            print_error "C program does not see modified uname"
        fi
        rm -f test_uname test_uname.c
    else
        print_error "Failed to compile C test program"
    fi
}

# Function to restore original state
restore_original_state() {
    print_header "Restoring Original State"
    
    # Clear all rules
    echo "clear" > /proc/deception/rules
    
    # Verify original uname is restored
    ORIGINAL_SYSNAME=$(uname -s)
    if [[ "$ORIGINAL_SYSNAME" != "FakeOS" && "$ORIGINAL_SYSNAME" != "PersistentOS" && "$ORIGINAL_SYSNAME" != "MultiProcessOS" ]]; then
        print_success "Original uname restored"
    else
        print_error "Original uname not restored"
    fi
    
    print_info "Original system name: $ORIGINAL_SYSNAME"
}

# Function to print summary
print_summary() {
    print_header "Test Summary"
    
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    
    TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        SUCCESS_RATE=$((TESTS_PASSED * 100 / TOTAL_TESTS))
        echo -e "${BLUE}Success Rate: $SUCCESS_RATE%${NC}"
    fi
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}All tests passed! Deception framework is working correctly.${NC}"
    else
        echo -e "${RED}Some tests failed. Check the output above for details.${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Deception Framework Test Suite${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
    
    # Check deception framework
    if ! check_deception_framework; then
        echo -e "${RED}Deception framework not available. Exiting.${NC}"
        exit 1
    fi
    
    # Run all tests
    test_uname_hooking
    test_rule_management
    test_error_handling
    test_persistence
    test_multiple_processes
    restore_original_state
    
    # Print summary
    print_summary
}

# Run main function
main "$@" 