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

sed -i 's/>Facet</>Facet-Demo</g' src/components/admin/AdminHeader.svelte

sed -i 's/Sign In | Facet/Sign In | Facet-Demo/g' src/routes/admin/login/+page.svelte
sed -i 's/Sign in to Facet/Sign in to Facet-Demo/g' src/routes/admin/login/+page.svelte
sed -i 's/placeholder="admin@example.com"/placeholder="demo@example.com"/g' src/routes/admin/login/+page.svelte

cat > src/components/admin/DemoBanner.svelte << 'SVELTE_EOF'
<script lang="ts">
    let dismissed = $state(false);
</script>

{#if !dismissed}
<div class="fixed top-16 left-0 right-0 z-30 bg-amber-500 text-amber-950 text-center py-2 px-4 text-sm font-medium shadow-sm">
    <span>
        🎭 Public Demo — Data resets daily at midnight UTC — 
        <span class="font-semibold">Login: demo@example.com / demo123</span>
    </span>
    <button 
        onclick={() => dismissed = true}
        class="ml-4 text-amber-800 hover:text-amber-950 font-bold"
        aria-label="Dismiss banner"
    >
        ✕
    </button>
</div>
{/if}
SVELTE_EOF

sed -i "/import AdminHeader from/a\\	import DemoBanner from '\$components/admin/DemoBanner.svelte';" src/routes/admin/+layout.svelte
sed -i 's/<AdminHeader \/>/<AdminHeader \/>\n\t\t<DemoBanner \/>/g' src/routes/admin/+layout.svelte
sed -i 's/mt-16">/mt-28">/g' src/routes/admin/+layout.svelte

sed -i 's/<div class="relative flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-700/<div class="hidden relative flex items-center gap-2 px-3 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-700/g' src/components/admin/AdminHeader.svelte

echo "Frontend transforms complete!"
