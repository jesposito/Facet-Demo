#!/bin/sh
set -e

echo "Applying Facet-Demo frontend transformations..."

WORKDIR="${1:-.}"
cd "$WORKDIR"

echo "Working in: $(pwd)"

SETTINGS_FILE="src/routes/admin/settings/+page.svelte"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Removing password section from settings..."
    
    awk '
    /let passwordForm = \$state/ { in_password_form = 1 }
    in_password_form && /\}\);/ { in_password_form = 0; next }
    in_password_form { next }
    
    /async function changePassword\(\)/ { in_change_password = 1 }
    in_change_password && /^[[:space:]]*\}$/ { 
        if (brace_count == 0) { in_change_password = 0; next }
    }
    in_change_password { 
        gsub(/{/, "{"); brace_count += gsub(/{/, "{")
        gsub(/}/, "}"); brace_count -= gsub(/}/, "}")
        next 
    }
    
    /<!-- Security section -->/ { in_security = 1 }
    in_security && /<!-- Public site controls -->/ { in_security = 0 }
    in_security { next }
    
    { print }
    ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
fi

echo "Frontend transforms complete!"
