#!/bin/bash

# Deception Framework Kernel Build Script
# This script builds and installs the modified kernel with deception framework

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KERNEL_VERSION="$(make kernelversion)"
BUILD_DIR="$(pwd)"
CONFIG_FILE=".config"
JOBS=$(nproc)

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Deception Framework Build${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Kernel Version: ${KERNEL_VERSION}${NC}"
echo -e "${BLUE}Build Directory: ${BUILD_DIR}${NC}"
echo -e "${BLUE}Jobs: ${JOBS}${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_error "Use: sudo $0"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    print_status "Checking build dependencies..."
    
    local missing_deps=()
    
    # Check for required packages (openSUSE Leap with zypper)
    for dep in gcc make bison flex bc libopenssl-devel libelf-devel ncurses-devel; do
        if ! rpm -q "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_status "Install with: sudo zypper install ${missing_deps[*]}"
        exit 1
    fi
    
    print_status "All dependencies satisfied"
}

# Clean previous build
clean_build() {
    print_status "Cleaning previous build artifacts..."
    make clean
    print_status "Clean completed"
}

# Configure kernel
configure_kernel() {
    print_status "Configuring kernel..."
    
    # Use default configuration for maximum compatibility
    print_status "Using default configuration..."
    make defconfig
    
    # Configure SUSE version for SLE15-SP6
    print_status "Configuring SUSE version..."
    echo "CONFIG_SUSE_KERNEL=y" >> "$CONFIG_FILE"
    echo "CONFIG_SUSE_PRODUCT_SLE=y" >> "$CONFIG_FILE"
    echo "CONFIG_SUSE_PRODUCT_CODE=1" >> "$CONFIG_FILE"
    echo "CONFIG_SUSE_VERSION=15" >> "$CONFIG_FILE"
    echo "CONFIG_SUSE_PATCHLEVEL=6" >> "$CONFIG_FILE"
    echo "CONFIG_SUSE_AUXRELEASE=0" >> "$CONFIG_FILE"
    
    # Enable comprehensive drivers for QEMU + BTRFS
    print_status "Enabling comprehensive drivers for QEMU + BTRFS..."
    
    # Essential filesystems
    echo "CONFIG_BTRFS_FS=y" >> "$CONFIG_FILE"
    echo "CONFIG_EXT4_FS=y" >> "$CONFIG_FILE"
    echo "CONFIG_XFS_FS=y" >> "$CONFIG_FILE"
    echo "CONFIG_OVERLAY_FS=y" >> "$CONFIG_FILE"
    echo "CONFIG_DEVTMPFS=y" >> "$CONFIG_FILE"
    echo "CONFIG_DEVTMPFS_MOUNT=y" >> "$CONFIG_FILE"
    
    # QEMU/Virtualization drivers
    echo "CONFIG_KVM_GUEST=y" >> "$CONFIG_FILE"
    echo "CONFIG_HYPERVISOR_GUEST=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_BLK=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_NET=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_CONSOLE=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_BALLOON=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_INPUT=y" >> "$CONFIG_FILE"
    echo "CONFIG_VIRTIO_MMIO=y" >> "$CONFIG_FILE"
    
    # Block device drivers
    echo "CONFIG_BLK_DEV=y" >> "$CONFIG_FILE"
    echo "CONFIG_BLK_DEV_SD=y" >> "$CONFIG_FILE"
    echo "CONFIG_SCSI=y" >> "$CONFIG_FILE"
    echo "CONFIG_SCSI_VIRTIO=y" >> "$CONFIG_FILE"
    echo "CONFIG_BLK_DEV_BSG=y" >> "$CONFIG_FILE"
    echo "CONFIG_BLK_DEV_THROTTLING=y" >> "$CONFIG_FILE"
    
    # Network drivers
    echo "CONFIG_NETDEVICES=y" >> "$CONFIG_FILE"
    echo "CONFIG_NET_CORE=y" >> "$CONFIG_FILE"
    echo "CONFIG_INET=y" >> "$CONFIG_FILE"
    echo "CONFIG_NET=y" >> "$CONFIG_FILE"
    
    # Input/Display drivers for QEMU
    echo "CONFIG_INPUT=y" >> "$CONFIG_FILE"
    echo "CONFIG_INPUT_KEYBOARD=y" >> "$CONFIG_FILE"
    echo "CONFIG_INPUT_MOUSE=y" >> "$CONFIG_FILE"
    echo "CONFIG_DRM=y" >> "$CONFIG_FILE"
    echo "CONFIG_DRM_BOCHS=y" >> "$CONFIG_FILE"
    echo "CONFIG_DRM_VIRTIO_GPU=y" >> "$CONFIG_FILE"
    echo "CONFIG_FB=y" >> "$CONFIG_FILE"
    echo "CONFIG_FB_SIMPLE=y" >> "$CONFIG_FILE"
    
    # Serial/Console drivers
    echo "CONFIG_SERIAL_8250=y" >> "$CONFIG_FILE"
    echo "CONFIG_SERIAL_8250_CONSOLE=y" >> "$CONFIG_FILE"
    echo "CONFIG_VT=y" >> "$CONFIG_FILE"
    echo "CONFIG_VT_CONSOLE=y" >> "$CONFIG_FILE"
    echo "CONFIG_HW_CONSOLE=y" >> "$CONFIG_FILE"
    
    # Only enable the deception framework
    print_status "Enabling Deception Framework..."
    echo "CONFIG_DECEPTION_FRAMEWORK=y" >> "$CONFIG_FILE"
    
    print_status "Configuration completed"
}

# Build kernel
build_kernel() {
    print_status "Building kernel with ${JOBS} jobs..."
    
    # Build kernel
    make -j${JOBS}
    
    if [[ $? -eq 0 ]]; then
        print_status "Kernel build completed successfully"
    else
        print_error "Kernel build failed"
        exit 1
    fi
}

# Install kernel
install_kernel() {
    print_status "Installing kernel..."
    
    # Install modules
    print_status "Installing kernel modules..."
    make modules_install
    if [[ $? -ne 0 ]]; then
        print_error "Module installation failed"
        exit 1
    fi
    
    # Install kernel
    print_status "Installing kernel image..."
    make install
    if [[ $? -ne 0 ]]; then
        print_error "Kernel installation failed"
        exit 1
    fi
    
    # Verify kernel was installed
    KERNEL_VERSION=$(make kernelversion)
    if [[ -f "/boot/vmlinuz-${KERNEL_VERSION}" ]]; then
        print_status "Kernel verified: /boot/vmlinuz-${KERNEL_VERSION}"
    else
        print_error "Kernel not found in /boot/"
        print_status "Attempting manual installation..."
        sudo cp arch/x86/boot/bzImage "/boot/vmlinuz-${KERNEL_VERSION}"
        if [[ $? -eq 0 ]]; then
            print_status "Manual kernel installation successful"
        else
            print_error "Manual kernel installation failed"
            exit 1
        fi
    fi
    
    # Create initramfs for the new kernel
    print_status "Creating initramfs..."
    INITRAMFS="/boot/initrd-${KERNEL_VERSION}"
    if command -v dracut >/dev/null 2>&1; then
        # Use the full kernel version that was actually installed
        FULL_KERNEL_VERSION=$(ls /lib/modules/ | grep deceptionframework | head -1)
        if [[ -n "$FULL_KERNEL_VERSION" ]]; then
            sudo dracut --force "$INITRAMFS" "$FULL_KERNEL_VERSION"
            if [[ $? -eq 0 ]]; then
                print_status "Initramfs created with dracut for $FULL_KERNEL_VERSION"
            else
                print_error "Failed to create initramfs with dracut"
            fi
        else
            print_warning "Could not find deception framework kernel modules"
            print_warning "Skipping initramfs creation"
        fi
    elif command -v mkinitrd >/dev/null 2>&1; then
        sudo mkinitrd "$INITRAMFS" "$KERNEL_VERSION"
        if [[ $? -eq 0 ]]; then
            print_status "Initramfs created with mkinitrd"
        else
            print_error "Failed to create initramfs with mkinitrd"
        fi
    else
        print_warning "No initramfs tool found - this may cause boot issues"
        print_warning "Please install dracut or mkinitrd"
    fi
    
    print_status "Kernel installation completed"
}

# Update bootloader
update_bootloader() {
    print_status "Updating bootloader..."
    
    # Update grub for openSUSE
    if command -v grub2-mkconfig &> /dev/null; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
        if [[ $? -eq 0 ]]; then
            print_status "GRUB2 updated for openSUSE"
        else
            print_error "GRUB2 update failed"
            exit 1
        fi
        
        # Verify new kernel is in GRUB config
        KERNEL_VERSION=$(make kernelversion)
        if grep -q "${KERNEL_VERSION}" /boot/grub2/grub.cfg; then
            print_status "New kernel found in GRUB configuration"
        else
            print_warning "New kernel not found in GRUB configuration"
            print_warning "You may need to manually select the kernel during boot"
        fi
    elif command -v update-grub &> /dev/null; then
        update-grub
        print_status "GRUB updated"
    else
        print_warning "Could not update bootloader automatically"
        print_warning "Please update your bootloader manually with: grub2-mkconfig -o /boot/grub2/grub.cfg"
    fi
}

# Create test script
create_test_script() {
    print_status "Creating test script..."
    
    cat > test_deception.sh << 'EOF'
#!/bin/bash

# Deception Framework Test Script

echo "=================================="
echo "  Deception Framework Test"
echo "=================================="

# Check if deception framework is loaded
if [[ -d "/proc/deception" ]]; then
    echo "[INFO] Deception framework is active"
else
    echo "[ERROR] Deception framework not found"
    exit 1
fi

# Test 1: Check original uname
echo ""
echo "Test 1: Original uname output"
echo "Original system name: $(uname -s)"

# Test 2: Add deception rule
echo ""
echo "Test 2: Adding deception rule"
echo "add:uname:Linux:DeceptionOS:/" > /proc/deception/rules

# Test 3: Check modified uname
echo ""
echo "Test 3: Modified uname output"
echo "Modified system name: $(uname -s)"

# Test 4: List rules
echo ""
echo "Test 4: Current rules"
cat /proc/deception/rules

# Test 5: Clear rules
echo ""
echo "Test 5: Clearing rules"
echo "clear" > /proc/deception/rules

# Test 6: Verify original restored
echo ""
echo "Test 6: Original uname restored"
echo "Restored system name: $(uname -s)"

echo ""
echo "Test completed!"
EOF

    chmod +x test_deception.sh
    print_status "Test script created: test_deception.sh"
}

# Main build process
main() {
    echo -e "${BLUE}Starting Deception Framework build...${NC}"
    echo ""
    
    # Check if running as root
    check_root
    
    # Check dependencies
    check_dependencies
    
    # Clean previous build
    clean_build
    
    # Configure kernel
    configure_kernel
    
    # Build kernel
    build_kernel
    
    # Install kernel
    install_kernel
    
    # Update bootloader
    update_bootloader
    
    # Create test script
    create_test_script
    
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Build completed successfully!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${YELLOW}1. Reboot to load the new kernel${NC}"
    echo -e "${YELLOW}2. Run: ./test_deception.sh${NC}"
    echo -e "${YELLOW}3. Check: cat /proc/deception/rules${NC}"
    echo ""
    echo -e "${BLUE}Build artifacts:${NC}"
    echo -e "${BLUE}- Kernel: /boot/vmlinuz-${KERNEL_VERSION}${NC}"
    echo -e "${BLUE}- Modules: /lib/modules/${KERNEL_VERSION}${NC}"
    echo -e "${BLUE}- Config: /boot/config-${KERNEL_VERSION}${NC}"
}

# Run main function
main "$@" 