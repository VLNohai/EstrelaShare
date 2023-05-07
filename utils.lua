utils = {}
open = io.open;

function utils.makeTrue(...)
    return true;
end

function utils.createStack()
    local stack = {size = 0, values = {}, top = nil};
    print('created new stack with size ' .. stack.size);

    function stack:push(element)
        print('pushed ' .. element);
        self.size = self.size + 1; self.values[self.size] = element; self.top = element; 
    end

    function stack:pop()
        if self.size > 0 then
            self.size = self.size - 1;
            self.top = self.values[self.size];
        else
            self.top = nil;
        end
    end

    return stack;
end

function utils.dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. utils.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

function utils.dump_print(o)
    print(utils.dump(o));
end

function utils.reverse(list)
    for i=1, #list/2, 1 do
        print(i);
        list[i], list[#list - i + 1] = list[#list - i + 1], list[i];
    end
    return list;
end

function utils.flatten(o)
    if #o == 1 then
        o = o[1];
    end
    return o;
end

return utils;