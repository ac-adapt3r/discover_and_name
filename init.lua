local storage = core.get_mod_storage()
local named_items = core.parse_json(storage:get_string("named_items")) or {}

local original_ItemStack = ItemStack

ItemStack = function(item)
    local itemstack = original_ItemStack(item)
    
    if core.registered_items[itemstack:get_name()] then
        local meta = itemstack:get_meta()
        meta:set_string("description", core.registered_items[itemstack:get_name()].description) 
    end

    return itemstack
end

minetest.register_on_player_inventory_action(function(player, action, inventory, inventory_info)
    if action == "put" then
        local itemstack = inventory_info.stack
        local meta = itemstack:get_meta()
        meta:set_string("description", core.registered_items[itemstack:get_name()].description)
    end
end)

core.register_on_mods_loaded(function()
    for name, _ in pairs(core.registered_items) do
        core.override_item(name, {description = named_items[name] or "Unknown Item"})
    end
    for name, def in pairs(core.registered_nodes) do
        local original_preserve = def.preserve_metadata
        core.override_item(name, {
            description = named_items[name] or "Unknown Node",
            
            preserve_metadata = function(pos, oldnode, oldmeta, drops)
                if original_preserve then
                    original_preserve(pos, oldnode, oldmeta, drops)
                end
    
                if drops and drops[1] then
                    local itemstack = drops[1]
                    local meta = itemstack:get_meta()
                    meta:set_string("description", core.registered_items[itemstack:get_name()].description)
                end
            end
    })
    end
end)

core.register_chatcommand("name_item", {
    privs = {
        interact = true,
    },
    description = "Name item",
    func = function(name, param)
        local item = core.get_player_by_name(name):get_wielded_item()
        local item_name = item:get_name()
        if not item:is_empty() and named_items[item_name] == nil then
            core.override_item(item_name, {description = param})

            for _, player in ipairs(core.get_connected_players()) do
                local inv = player:get_inventory()
                local lists = {"main", "craft"}
                for _, list in pairs(lists) do
                    local size = inv:get_size(list)
                    for i = 1, size do
                        local stack = inv:get_stack(list, i)

                        if not stack:is_empty() and stack:get_name() == item_name then
                            local meta = stack:get_meta()
                            meta:set_string("description", param)
                            inv:set_stack(list, i, stack)
                        end
                    end
                end
            end

            named_items[item_name] = param
            storage:set_string("named_items", core.write_json(named_items))
            return true, "Item successfully named \"" .. param .. "\""
        elseif item:is_empty() then
            return false, "No items in hand, please wield the item you want to name"
        else
            return false, "This item is already named"
        end
    end,
})

core.register_privilege("remove_item_name", {
    description = "Can remove item names",
    give_to_singleplayer = false
})

core.register_chatcommand("remove_item_name", {
    privs = {
        remove_item_name = true,
    },
    description = "Remove item name",
    func = function(name, param)
        local item = core.get_player_by_name(name):get_wielded_item()
        local item_name = item:get_name()
        if not item:is_empty() and named_items[item_name] ~= nil then
            if core.registered_nodes[item_name] then
                core.override_item(item_name, {description = "Unknown Node"})
            else
                core.override_item(item_name, {description = "Unknown Item"})
            end

            for _, player in ipairs(core.get_connected_players()) do
                local inv = player:get_inventory()
                local lists = {"main", "craft"}
                for _, list in pairs(lists) do
                    local size = inv:get_size(list)
                    for i = 1, size do
                        local stack = inv:get_stack(list, i)

                        if not stack:is_empty() and stack:get_name() == item_name then
                            local meta = stack:get_meta()
                            if core.registered_nodes[item_name] then
                                meta:set_string("description", "Unknown Node")
                            else
                                meta:set_string("description", "Unknown Item")
                            end
                            inv:set_stack(list, i, stack)
                        end
                    end
                end
            end

            named_items[item_name] = nil
            storage:set_string("named_items", core.write_json(named_items))
            return true, "Item name successfully removed"
        elseif item:is_empty() then
            return false, "No items in hand, please wield the item which name you want to remove"
        else
            return false, "This item isn't named yet"
        end
    end,
})
