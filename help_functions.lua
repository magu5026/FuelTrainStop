function exists(tab,element)
	local v
	for _,v in pairs(tab) do
		if v == element then
			return true
		elseif type(v) == "table" then
			return exists(v,element)
		end
	end
	return false
end


function count(list)
	local i = 0
	for _,element in pairs(list) do
		i = i + 1
	end
	return i
end 