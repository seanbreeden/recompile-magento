#!/bin/bash
set -euo pipefail

clear
echo -e "\e[38;5;3m"
echo -e "██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗██╗     ██╗███╗   ██╗ ██████╗    \e[38;5;5m ███╗   ███╗ █████╗  ██████╗ ███████╗███╗   ██╗████████╗ ██████╗  \e[38;5;3m"
echo -e "██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║██║     ██║████╗  ██║██╔════╝    \e[38;5;5m ████╗ ████║██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗ \e[38;5;3m"
echo -e "██████╔╝█████╗  ██║     ██║   ██║██╔████╔██║██████╔╝██║██║     ██║██╔██╗ ██║██║  ███╗   \e[38;5;5m ██╔████╔██║███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   ██║   ██║ \e[38;5;3m"
echo -e "██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║██║     ██║██║╚██╗██║██║   ██║   \e[38;5;5m ██║╚██╔╝██║██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   ██║   ██║ \e[38;5;3m"
echo -e "██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ██║███████╗██║██║ ╚████║╚██████╔╝   \e[38;5;5m ██║ ╚═╝ ██║██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   ╚██████╔╝ \e[38;5;3m"
echo -e "╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝    \e[38;5;5m ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝  \e[38;5;3m"
echo -e "\e[0m"
echo
echo -e "\e[41m ****ATTENTION**** \e[0m This will recompile Magento!"
echo
read -n 1 -s -r -p 'Press any key to continue or CTRL+C to abort.'
echo
echo

# Step 1: Composer install
echo -e "\e[42m                                                           \e[0m"
echo -e "\e[42m Running composer install...                               \e[0m"
echo -e "\e[42m                                                           \e[0m"
echo
composer install
echo

# Step 2: Apply patches (before compilation so changes are picked up)
echo -e "\e[43m                                                           \e[0m"
echo -e "\e[43m Applying patches...                                       \e[0m"
echo -e "\e[43m                                                           \e[0m"
echo
if [ -f ./vendor/bin/ece-patches ]; then
    php ./vendor/bin/ece-patches apply
else
    echo "Patch tool not found. Skipping patch application."
fi
echo

# Step 3: Delete generated code
echo -e "\e[44m                                                           \e[0m"
echo -e "\e[44m Deleting generated folder...                              \e[0m"
echo -e "\e[44m                                                           \e[0m"
echo
rm -rf generated/code/* generated/metadata/* 2>/dev/null || true
echo

# Step 4: Run setup:upgrade
echo -e "\e[45m                                                           \e[0m"
echo -e "\e[45m Running setup:upgrade...                                  \e[0m"
echo -e "\e[45m                                                           \e[0m"
echo
php bin/magento setup:upgrade
echo

# Step 5: Compile dependency injection (must run before static content deploy)
echo -e "\e[46m                                                           \e[0m"
echo -e "\e[46m Running dependency injection compilation...               \e[0m"
echo -e "\e[46m                                                           \e[0m"
echo
php bin/magento setup:di:compile
echo

# Step 6: Remove & deploy static content
echo -e "\e[41m                                                           \e[0m"
echo -e "\e[41m Removing & deploying static content...                    \e[0m"
echo -e "\e[41m                                                           \e[0m"
echo
rm -rf pub/static/_cache pub/static/frontend pub/static/adminhtml pub/static/_requirejs pub/static/deployed_version.txt 2>/dev/null || true
rm -rf var/view_preprocessed/* 2>/dev/null || true
php bin/magento setup:static-content:deploy -f
echo

# Step 7: Flush caches
echo -e "\e[43m                                                           \e[0m"
echo -e "\e[43m Flushing caches...                                        \e[0m"
echo -e "\e[43m                                                           \e[0m"
echo
php bin/magento cache:clean
echo
php bin/magento cache:flush
echo

# Step 8: Reindex
echo -e "\e[45m                                                           \e[0m"
echo -e "\e[45m Reindexing...                                             \e[0m"
echo -e "\e[45m                                                           \e[0m"
echo
php bin/magento indexer:reset
echo
php bin/magento indexer:reindex
echo

# Complete
echo -e "\e[42m                                                           \e[0m"
echo -e "\e[42m Complete.                                                 \e[0m"
echo -e "\e[42m                                                           \e[0m"
echo
echo

# Display site information
baseurl=$(php bin/magento config:show web/secure/base_url)
echo -e " Site URL: ${baseurl}"
adminuri=$(php bin/magento info:adminuri)
echo -e " ${adminuri}"

# Check cache type and offer to switch from Varnish/Fastly to Built-in for local dev
# Magento cache application values: 1 = Built-in, 2 = Varnish, 42 = Fastly CDN
cache=$(php bin/magento config:show system/full_page_cache/caching_application)
if [[ "$cache" == "2" || "$cache" == "42" ]]; then
    if [[ "$cache" == "42" ]]; then
        cachetype="Fastly CDN"
    else
        cachetype="Varnish"
    fi
    echo
    echo -n "Cache is set to ${cachetype}. Change to Built-in Cache (recommended for local)? [Y/N] "
    read -n 1 changecache
    echo
    case $changecache in
        [Yy]*)
            php bin/magento config:set system/full_page_cache/caching_application 1
            php bin/magento cache:flush
            echo "Changed caching to Built-in Cache."
            ;;
        [Nn]*)
            echo "No changes made. ${cachetype} is still set as the cache."
            ;;
        *)
            echo "No changes made."
            ;;
    esac
    cache=$(php bin/magento config:show system/full_page_cache/caching_application)
fi

if [[ "$cache" == "1" ]]; then
    cachetype="Built-in Cache"
elif [[ "$cache" == "2" ]]; then
    cachetype="Varnish"
elif [[ "$cache" == "42" ]]; then
    cachetype="Fastly CDN"
else
    cachetype="Unknown (${cache})"
fi
echo -e "    Cache: ${cachetype}"
echo
echo
