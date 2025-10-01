local utils = {}

---@param action string The action you wish to target
---@param data any The data you wish to send along with this action
function utils.SendReactMessage(action, data)
	SendNUIMessage({
		action = action,
		data = data
	})
end

function utils.ShowNUI(action, shouldShow)
    SetNuiFocus(shouldShow, shouldShow)
	SendNUIMessage({
		action = action,
		data = shouldShow
	})
end


return utils