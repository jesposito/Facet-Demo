#!/bin/sh
set -e

echo "Applying Facet-Demo frontend transformations..."

WORKDIR="${1:-.}"
cd "$WORKDIR"

echo "Working in: $(pwd)"

LAYOUT_FILE="src/routes/admin/+layout.svelte"
if [ -f "$LAYOUT_FILE" ]; then
    echo "Patching admin layout..."
    
    sed -i "/import PasswordChangeModal/d" "$LAYOUT_FILE"
    sed -i "/let showPasswordChangeModal/d" "$LAYOUT_FILE"
    sed -i "/checkDefaultPassword/d" "$LAYOUT_FILE"
    sed -i "/showPasswordChangeModal/d" "$LAYOUT_FILE"
    sed -i "/PasswordChangeModal/d" "$LAYOUT_FILE"
    sed -i "/has_default_password/d" "$LAYOUT_FILE"
    sed -i "/handlePasswordChanged/d" "$LAYOUT_FILE"
    sed -i "/Password was successfully/d" "$LAYOUT_FILE"
    sed -i "/password_changed_from_default/d" "$LAYOUT_FILE"
    sed -i "/Password change modal/d" "$LAYOUT_FILE"
fi

SETTINGS_FILE="src/routes/admin/settings/+page.svelte"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Patching settings page..."
    
    awk '
    /<!-- Security section -->/ { skip = 1; next }
    /<!-- Public site controls -->/ { skip = 0 }
    !skip { print }
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    
    sed -i "/passwordForm/d" "$SETTINGS_FILE"
    sed -i "/changePassword/d" "$SETTINGS_FILE"
    sed -i "/async function changePassword/,/^[[:space:]]*}/d" "$SETTINGS_FILE" 2>/dev/null || true
fi

echo "Frontend transformations complete!"
