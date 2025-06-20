#include <efi.h>
#include <efilib.h>

// Program entrypoint
EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {

	// Initialize the standard EFI library
	InitializeLib(ImageHandle, SystemTable);

	// Print message
	Print(L"Hello, World!\n");

	// Return from program
	return EFI_SUCCESS;
}

