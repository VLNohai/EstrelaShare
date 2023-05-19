TokenType = require('tokens').TokenType;
NodeType = require('tokens').NodeType;
Utils = require('utils');

Parser = {}

NODE = {}
LEXEMS = {}
INDEX = 1;

MAX_INDEX = -1;

function EQUALS(a, b)
    if a == b then
        INDEX = INDEX + 1;
        if INDEX > MAX_INDEX then
            MAX_INDEX = INDEX;
        end
        return a;
    end
    return false;
end

function SET(a, b)
    if b then
        a.val = b;
        return a.val;
    else
        return b;
    end
end

function OPTIONAL(index, ...)

    local indexCpy = index;
    local arg = {...}
    local astElements = {};

    if #arg > (#LEXEMS - INDEX + 1) then
        return {};
    end
    
    for key, value in pairs(arg) do
        local astNode = {val = nil};
        if type(value) == 'number' then
            if not SET(astNode, EQUALS(LEXEMS[INDEX].tokenType, value)) then
                INDEX = indexCpy;
                astElements[#astElements] = nil; 
                break;
            else
                astElements[#astElements + 1] = LEXEMS[INDEX - 1];
            end
        elseif type(value) == 'function' then
            if not SET(astNode, value()) then
                INDEX = indexCpy;
                astElements[#astElements] = nil;
                break;
            else
                astElements[#astElements + 1] = astNode.val;
            end
        else
            print('weird error');
        end

    end
    astElements = utils.flatten(astElements);
    return astElements;
end

function OPTIONAL_MULTIPLE(index, ...)

    local matched = true;
    local indexCpy = INDEX;
    local astElements = {};

    local arg = {...}

    if #arg > (#LEXEMS - INDEX + 1) then
        return {};
    end
    
    local repetitions = 1;
    while(matched and #arg <= (#LEXEMS - INDEX + 1)) do

        local astNode = {val = nil};
        astElements[repetitions] = {};

        for key, value in ipairs(arg) do
            if type(value) == 'number' then
                if not SET(astNode, EQUALS(LEXEMS[INDEX].tokenType, value)) then
                    INDEX = indexCpy;
                    matched = false;
                    astElements[repetitions] = nil;
                    break;
                else
                    astElements[repetitions][#astElements[repetitions] + 1] = LEXEMS[INDEX - 1];
                end
            elseif type(value) == 'function' then
                if not SET(astNode, value()) then
                    INDEX = indexCpy;
                    matched = false;
                    astElements[repetitions] = nil;
                    break;
                else
                    astElements[repetitions][#astElements[repetitions] + 1] = astNode.val;
                end
            else
                matched = false;
                break;
            end
        end

        if(matched) then
        indexCpy = INDEX;
        astElements[repetitions] = utils.flatten(astElements[repetitions]);
        repetitions = repetitions + 1;
        end
    end
    INDEX = indexCpy;
    --astElements = utils.flatten(astElements);
    return astElements;
end

function OPTIONAL_MULTIPLE_LEAVE_LAST(index, ...)

    local matched = true;
    local indexCpy = INDEX;
    local earlyIndex = INDEX;
    local astElements = {};

    local arg = {...}

    if #arg > (#LEXEMS - INDEX + 1) then
        return {};
    end
    
    local repetitions = 1;
    while(matched and #arg <= (#LEXEMS - INDEX + 1)) do

        local astNode = {val = nil};
        astElements[repetitions] = {};

        for key, value in ipairs(arg) do
            if type(value) == 'number' then
                if not SET(astNode, EQUALS(LEXEMS[INDEX].tokenType, value)) then
                    INDEX = indexCpy;
                    matched = false;
                    astElements[repetitions] = nil;
                    break;
                else
                    astElements[repetitions][#astElements[repetitions] + 1] = LEXEMS[INDEX - 1];
                end
            elseif type(value) == 'function' then
                if not SET(astNode, value()) then
                    INDEX = indexCpy;
                    matched = false;
                    astElements[repetitions] = nil;
                    break;
                else
                    astElements[repetitions][#astElements[repetitions] + 1] = astNode.val;
                end
            else
                matched = false;
                break;
            end
        end

        if(matched) then
        earlyIndex = indexCpy;
        indexCpy = INDEX;
        astElements[repetitions] = utils.flatten(astElements[repetitions]);
        repetitions = repetitions + 1;
        end

    end
    INDEX = earlyIndex;

    if #astElements > 0 then
        astElements[#astElements] = nil;
    end
    --astElements = utils.flatten(astElements);
    return astElements;
end

function MATCH(...)
    local indexCpy = INDEX;
    local arg = {...}

    local astElements = {};

    if #arg > (#LEXEMS - INDEX + 1) then
        return false;
    end

    if(#arg == 0) then print('received null...') return false; end;

    for key, value in ipairs(arg) do
        local localIndex = INDEX;
        local astNode = {val = nil};
        if type(value) == 'function' then
            if not SET(astNode, value()) then 
                return false; 
            else
                astElements[#astElements + 1] = astNode.val;
            end
        elseif type(value) == 'number' then
            if not SET(astNode, EQUALS(LEXEMS[INDEX].tokenType, value)) then 
                INDEX = indexCpy; return false; 
            else
                astElements[#astElements + 1] = LEXEMS[INDEX - 1];
            end
        else
            print('weird error');
        end
    end
    astElements = utils.flatten(astElements);
    return astElements;
end

function ONE_OR_MORE(index, ...)
    local indexCpy = INDEX;
    local arg = {...}

    local firstMatch = {val = nil};
    local listMatch = {val = nil};
    if SET(firstMatch, MATCH(table.unpack(arg))) and SET(listMatch, OPTIONAL_MULTIPLE(INDEX, table.unpack(arg))) then
        local result = firstMatch.val;
        for _, value in ipairs(listMatch) do
            result[#result+1] = value;
        end
        return result;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.CHUNK()
    local ast = MATCH(NODE.BLOCK);
    if ast and INDEX == #LEXEMS + 1 then
        print('parsed succesfully');
        return ast;
    else
        print('syntax error!');
        print('error at line ' .. LEXEMS[MAX_INDEX].line .. ', column: ' .. LEXEMS[MAX_INDEX].column);
    end
end

function NODE.BLOCK()
    local indexCpy = INDEX;
    local stats = {value = nil};
    local retstat = {value = nil};

    if SET(stats, OPTIONAL_MULTIPLE(INDEX, NODE.STAT)) and SET(retstat, OPTIONAL(INDEX, NODE.RETSTAT)) then
        return {node = NodeType.BLOCK, stats = stats.val, retstat = retstat.val};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.STAT()

    local indexCpy = INDEX;
    local matchedValues = {val = nil};

    if MATCH(TokenType.SEMICOLON_MARK) then
        return {node = NodeType.SEMICOLON_NODE};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(NODE.VARLIST, TokenType.ASSIGN_OPERATOR, NODE.EXPLIST)) then
        return {node = NodeType.ASSIGNMENT_NODE, left = matchedValues.val[1], right = matchedValues.val[3]};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.LOCAL_KEYWORD, NODE.NAMELIST, TokenType.ASSIGN_OPERATOR, NODE.EXPLIST)) then
        return {node = NodeType.LOCAL_DECLARATION, left = matchedValues.val[2], right = matchedValues.val[4]};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(NODE.FUNCTIONCALL)) then
        return {node = NodeType.FUNCTION_CALL_NODE, call = matchedValues.val.call, prefix = matchedValues.val.prefix, suffix = matchedValues.val.suffix};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(NODE.LABEL)) then
        return {node = NodeType.LABEL, id = matchedValues.val.value};
    end
    INDEX = indexCpy;

    if MATCH(TokenType.BREAK_KEYWORD) then
        return {node = NodeType.BREAK};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.GOTO_KEYWORD, TokenType.IDENTIFIER)) then
        return {node = NodeType.GOTO, id = matchedValues.val[2].value};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.DO_KEYWORD, NODE.BLOCK, TokenType.END_KEYWORD)) then
        return {node = NodeType.DO_LOOP, block = matchedValues.val[2].value};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.WHILE_KEYWORD, NODE.EXP, TokenType.DO_KEYWORD, NODE.BLOCK, TokenType.END_KEYWORD)) then
        return {node = NodeType.WHILE_LOOP, condition = matchedValues.val[2], block = matchedValues.val[4]};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.REPEAT_KEYWORD, NODE.BLOCK, TokenType.UNTIL_KEYWORD, NODE.EXP)) then
        return {node = NodeType.REPEAT_LOOP_NODE, block = matchedValues.val[2], condition = matchedValues.val[4]};
    end
    INDEX = indexCpy;

    local mainExp = {val = nil};
    local elseifExp = {val = nil};
    local elseExp = {val = nil};
    if SET(mainExp, MATCH(TokenType.IF_KEYWORD, NODE.EXP, TokenType.THEN_KEYWORD, NODE.BLOCK)) and
    SET(elseifExp,
    OPTIONAL_MULTIPLE(
        INDEX, TokenType.ELSEIF_KEYWORD, NODE.EXP, TokenType.THEN_KEYWORD, NODE.BLOCK
    )) and
    SET(elseExp,
    OPTIONAL(
        INDEX, TokenType.ELSE_KEYWORD, NODE.BLOCK
    )) and
    MATCH(TokenType.END_KEYWORD) then
        local branches = {[1] = {}};
        branches[1].condition = mainExp.val[2];
        branches[1].block = mainExp.val[4];
        for key, branch in ipairs(elseifExp.val) do
            branches[#branches+1] = {};
            branches[#branches].condition = branch[2];
            branches[#branches].block = branch[4];
        end
        local elseBranch = nil;
        if #elseExp.val then
            elseBranch = {block = elseExp.val[2]}
        end
        return {node = NodeType.IF_NODE, branches = branches, elseBranch = elseBranch};
    end
    INDEX = indexCpy;

    local incrementExp = {val = nil};
    local forBody = {val = nil};
    if SET(matchedValues, MATCH(TokenType.FOR_KEYWORD, TokenType.IDENTIFIER, TokenType.ASSIGN_OPERATOR, 
             NODE.EXP, TokenType.COMMA_MARK, NODE.EXP)) and
    SET(incrementExp, OPTIONAL(
        INDEX, TokenType.COMMA_MARK, NODE.EXP
    )) and
    SET(forBody, MATCH(TokenType.DO_KEYWORD, NODE.BLOCK, TokenType.END_KEYWORD)) then
        local increment = nil;
        if #incrementExp.val > 0 then
            increment = incrementExp.val[2];
        end
        return {
            node = NodeType.FOR_CONTOR_LOOP_NODE,
            contorName = matchedValues.val[2].value,
            contorValue = matchedValues.val[4],
            stopValue = matchedValues.val[6],
            increment = increment,
            block = forBody.val[2]
        }
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.FOR_KEYWORD, NODE.NAMELIST, TokenType.IN_KEYWORD, NODE.EXPLIST, TokenType.DO_KEYWORD, NODE.BLOCK, TokenType.END_KEYWORD)) then
        return {
            node = NodeType.FOR_IN_LOOP_NODE,
            left = matchedValues.val[2],
            right = matchedValues.val[4],
            block = matchedValues.val[6]
        };
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.FUNCTION_KEYWORD, NODE.FUNCNAME, NODE.FUNCBODY)) then
        return {node = NodeType.FUNCTION_DECLARATION_NODE, id = matchedValues.val[2], body = matchedValues.val[3]};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.LOCAL_KEYWORD, TokenType.FUNCTION_KEYWORD, NODE.FUNCNAME, NODE.FUNCBODY)) then
        return {node = NodeType.LOCAL_FUNCTION_DECLARATION_NODE, id = matchedValues.val[3], body = matchedValues.val[4]};
    end
    INDEX = indexCpy;

    if SET(matchedValues, MATCH(TokenType.LOCAL_KEYWORD, NODE.ATTNAMELIST) and OPTIONAL(INDEX, TokenType.ASSIGN_OPERATOR, NODE.EXPLIST)) then
        return true;
    end
    INDEX = indexCpy;

    local className = {val = nil};
    local baseClassName = {val = nil};
    local classBody = {val = nil};
    if SET(className, MATCH(TokenType.CLASS_KEYWORD, TokenType.IDENTIFIER)) and 
    SET(baseClassName, OPTIONAL(INDEX, TokenType.COLON_OPERATOR, TokenType.IDENTIFIER)) and
    SET(classBody, MATCH(TokenType.AS_KEYWORD, NODE.CLASSBODY)) then
        local baseClassId = nil;
        if #baseClassName.val > 0 then
            baseClassId = baseClassName.val[2].value;
        end
        return {node = NodeType.CLASS_DECLARATION_NODE, id = className.val[2].value, baseClassId = baseClassId, stats = classBody.val[2].stats};
    end
    INDEX = indexCpy;

    local matchedNames = { val = nil };
    local matchedFunctions = { val = nil };
    local matchedID = {val = nil};
    local matchedUnique = {val = nil};
    if MATCH(TokenType.LOGIC_KEYWORD) and
    SET(matchedUnique, OPTIONAL(INDEX, TokenType.UNIQUE_KEYWORD)) and
    SET(matchedID, MATCH(TokenType.IDENTIFIER)) and
    SET(matchedNames, MATCH(NODE.LOGIC_NAMELIST)) and
    SET(matchedFunctions, OPTIONAL_MULTIPLE(INDEX, NODE.LOGIC_FUNC)) and 
    MATCH(TokenType.END_KEYWORD) then
        local is_unique = nil;
        if matchedUnique.val.value then
            is_unique = true;
        end
        return { node = NodeType.LOGIC_BLOCK_NODE, id = matchedID.val.value, is_unique = is_unique, args =  matchedNames.val, funcs = matchedFunctions.val};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.CLASSBODY()
    local indexCpy = INDEX;

    local stats = {val = nil};
    if SET(stats, OPTIONAL_MULTIPLE(INDEX, NODE.CLASSSTAT)) and MATCH(TokenType.END_KEYWORD) then
        return {node = NodeType.CLASS_BODY_NODE, stats = stats.val};
    end
    INDEX = indexCpy;

    return false
end

function NODE.CLASSSTAT()
    local indexCpy = INDEX;

    local funcBody = {val = nil};
    local accessMod = {val = nil};
    local staticMod = {val = nil};
    
    if MATCH(TokenType.SEMICOLON_MARK) then
        return {node = NodeType.SEMICOLON_NODE};
    end

    if MATCH(TokenType.STATIC_KEYWORD) and SET(funcBody, MATCH(TokenType.CONSTRUCTOR_KEYWORD, NODE.FUNCBODY)) then
        return {
            node = NodeType.STATIC_CONSTRUCTOR_NODE, 
            body = funcBody.val[2]
        };
    end
    INDEX = indexCpy;

    if SET(accessMod, OPTIONAL(INDEX, NODE.ACCESSMOD)) and SET(funcBody, MATCH(TokenType.CONSTRUCTOR_KEYWORD, NODE.FUNCBODY)) then
        local access = 'private';
        if #accessMod.val > 0 then
            access = accessMod.val
        end
        return {
            node = NodeType.CONSTRUCTOR_NODE, 
            body = funcBody.val[2], 
            access = access
        };
    end
    INDEX = indexCpy;

    if SET(accessMod, OPTIONAL(INDEX, NODE.ACCESSMOD)) and 
    SET(staticMod, OPTIONAL(INDEX, TokenType.STATIC_KEYWORD)) and 
    SET(funcBody, MATCH(TokenType.IDENTIFIER, NODE.FUNCBODY)) then
        local access = 'private';
        local static = nil;
        if #accessMod.val > 0 then
            access = accessMod.val;
        end
        if #staticMod.val > 0 then
            static = true;
        end
        return {
            node = NodeType.MEMBER_FUNCTION_NODE, 
            access = access, 
            static = static, 
            id = funcBody.val[1].value, 
            functionBody = funcBody.val[2]
        };
    end
    INDEX = indexCpy;

    local nameList = {val = nil};
    local expList = {val = nil};
    if SET(accessMod, OPTIONAL(INDEX, NODE.ACCESSMOD)) and 
    SET(staticMod, OPTIONAL(INDEX, TokenType.STATIC_KEYWORD)) and  
    SET(nameList, MATCH(NODE.NAMELIST)) and 
    SET(expList, MATCH(TokenType.ASSIGN_OPERATOR, NODE.EXPLIST)) then
        local access = 'private';
        local static = nil;
        if #accessMod.val > 0 then
            access = accessMod.val;
        end
        if #staticMod.val > 0 then
            static = true;
        end
        return {
            node = NodeType.FIELD_DELCARATION_NODE,
            access = access,
            static = static,
            left = nameList.val,
            right = expList.val[2]
        };
    end
    INDEX = indexCpy;

    return false
end

function NODE.ACCESSMOD()

    if MATCH(TokenType.PUBLIC_KEYWORD) then
        return 'public';
    end 
    if MATCH(TokenType.PRIVATE_KEYWORD) then
        return 'private';
    end 
    if MATCH(TokenType.PROTECTED_KEYWORD) then
        return 'protected';
    end
    
    return false;
end

function NODE.ATTNAMELIST()
    local indexCpy = INDEX;

    local firstAttrib = {val = nil};
    local attribList = {val = nil};
    if SET(firstAttrib, MATCH(TokenType.IDENTIFIER, NODE.ATTRIB)) and SET(attribList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, TokenType.IDENTIFIER, NODE.ATTRIB)) then
        local attributes = {};
        attributes[1] = {id = firstAttrib.val[1], attribute = firstAttrib.val[2]};
        --VERIFY THIS CONDITION
        if #attribList.val > 0 then
            for key, value in ipairs(attribList.val) do
                attributes[#attributes+1] = {id = value[2], attribute = value[3]};           
            end
        end
        return attribList;
    end
    INDEX = indexCpy;

    return false
end

function NODE.ATTRIB()
    local indexCpy = INDEX;
    
    local matchedValues = {val = nil};
    if SET(matchedValues, OPTIONAL(INDEX, TokenType.LESS_OPERATOR, TokenType.IDENTIFIER, TokenType.MORE_OPERATOR)) then
        local id = nil;
        if #matchedValues.val > 0 then
            id = matchedValues.val[2].value;
        end
        return {id = id};
    end
    INDEX = indexCpy;

    return false
end

function NODE.RETSTAT()
    local indexCpy = INDEX;

    local expressions = {value = nil};
    if MATCH(TokenType.RETURN_KEYWORD) and 
    SET(expressions, OPTIONAL(INDEX, NODE.EXPLIST)) and 
    OPTIONAL(INDEX, TokenType.SEMICOLON_MARK) then
        return {expressions = expressions.val};
    end
    INDEX = indexCpy;

    return false
end

function NODE.LABEL()
    local indexCpy = INDEX;
    local matchedValues = {val = nil};

    if SET(matchedValues, MATCH(TokenType.DOUBLE_COLON_OPERATOR, TokenType.IDENTIFIER, TokenType.DOUBLE_COLON_OPERATOR)) then
        return matchedValues.val[2];
    end

    INDEX = indexCpy;
    return false
end

function NODE.FUNCNAME()
    local indexCpy = INDEX;

    local root = {value = nil};
    local fields = {value = nil};
    local selfField = {value = nil};
    if SET(root, MATCH(TokenType.IDENTIFIER)) and 
    SET(fields, OPTIONAL_MULTIPLE(INDEX, TokenType.POINT_MARK, TokenType.IDENTIFIER)) and
    SET(selfField, OPTIONAL(INDEX, TokenType.COLON_OPERATOR, TokenType.IDENTIFIER)) then
        local fieldIdList = {};
        fieldIdList[1] = root.val.value;
        if #fields.val > 0 then
            for key, value in ipairs(fields.val) do
                fieldIdList[#fieldIdList+1] = value[2].value;
            end
        end
        local isSelf = false;
        if #selfField.val > 0 then
            fieldIdList[#fieldIdList+1] = selfField.val[2].value;
            isSelf = true;
        end
        fieldIdList.isSelf = isSelf; 
        return fieldIdList;
    end
    INDEX = indexCpy;

    return false
end

function NODE.VARLIST()
    local indexCpy = INDEX;

    local firstVar = {val = nil};
    local vars = {val = nil};
    if SET(firstVar, MATCH(NODE.VAR)) and SET(vars, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.VAR)) then
        local varList = {};
        varList[1] = firstVar.val;
        for key, value in ipairs(vars.val) do
            varList[#varList+1] = value[2];
        end
        varList.node = NodeType.VARLIST_NODE;
        return varList;
    end
    INDEX = indexCpy;

    return false
end

function NODE.VAR()
    local indexCpy = INDEX;

    local matchedThis = {val = nil};
    local matchedPrefix = {val = nil};
    local matchedSuffix = {val = nil};
    local matchedIndex = {val = nil};
    local matchedType = {val = nil};
    if SET(matchedThis, OPTIONAL(INDEX, TokenType.THIS_KEYWORD, TokenType.POINT_MARK)) and 
    SET(matchedPrefix, MATCH(NODE.PREFIX)) and 
    SET(matchedSuffix, OPTIONAL_MULTIPLE_LEAVE_LAST(INDEX, NODE.SUFFIX)) and 
    SET(matchedIndex, MATCH(NODE.INDEX)) then
        local hasThis = nil;
        local type = nil;
        local index = {};
        if #matchedThis.val > 0 then
            hasThis = true;
        end
        if matchedType.val and #matchedType.val > 0 then
            type = matchedType.val[2].value;
        end
        if #matchedSuffix.val > 0 then
            for key, value in pairs(matchedSuffix.val) do
                index[#index+1] = value;
            end
            matchedSuffix = utils.reverse(matchedSuffix);
        end
        index[#index+1] = matchedIndex.val;
        return {
            node = NodeType.VAR_NODE,
            isThis = hasThis,
            id = matchedPrefix.val,
            index = index,
            type = type
        };
    end
    INDEX = indexCpy;

    local matchedId = {val = nil};
    matchedType = {val = nil}
    if SET(matchedThis, OPTIONAL(INDEX, TokenType.THIS_KEYWORD, TokenType.POINT_MARK)) and 
    SET(matchedId, MATCH(TokenType.IDENTIFIER)) and 
    utils.makeTrue(
        SET(matchedType, MATCH(TokenType.AT_OPERATOR, TokenType.IDENTIFIER)) or
        SET(matchedType, MATCH(TokenType.AT_OPERATOR, TokenType.ANY_KEYWORD)) or
        SET(matchedType, MATCH(TokenType.AT_OPERATOR, TokenType.FUNCTION_KEYWORD))
    ) then
        local hasThis = nil;
        local type = nil;
        local nodeType = NodeType.VAR_NODE;
        if matchedThis and #matchedThis.val > 0 then
            hasThis = true;
        end
        if matchedType.val and #matchedType.val > 0 then
            type = matchedType.val[2].value;
            nodeType = NodeType.TYPED_VAR_NODE;
        end
        return {node = nodeType, isThis = hasThis, id = matchedId.val.value, type = type};
    end
    INDEX = indexCpy;

    return false
end

function NODE.NAMELIST()
    local indexCpy = INDEX;
    
    local matchedFirstName = {val = nil};
    local matchedNameList = {val = nil};
    if SET(matchedFirstName, MATCH(NODE.NAME)) and 
    SET(matchedNameList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.NAME)) then
        local nameList = {};
        nameList[1] = matchedFirstName.val;
        for key, value in ipairs(matchedNameList.val) do
           nameList[#nameList+1] = value[2]; 
        end
        return nameList;
    end
    INDEX = indexCpy;

    return false
end

function NODE.NAME()
    local indexCpy = INDEX;

    local matchedId = {val = nil};
    local matchedType = {val = nil};
    if SET(matchedId, MATCH(TokenType.IDENTIFIER)) and 
    utils.makeTrue(
        SET(matchedType, MATCH(TokenType.AT_OPERATOR, TokenType.IDENTIFIER)) or
        SET(matchedType, MATCH(TokenType.AT_OPERATOR, TokenType.ANY_KEYWORD))
    )  then
        local type = nil;
        if matchedType.val ~= nil then
            type = matchedType.val[2].value;
        end
        return {node = NodeType.NAME_NODE, id = matchedId.val.value, type = type};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.EXPLIST()
    local indexCpy = INDEX;

    local matchedFirstExp = {val = nil};
    local matchedExpList = {val = nil};
    if SET(matchedFirstExp, MATCH(NODE.EXP)) and
    SET(matchedExpList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.EXP)) then
        local expList = {};
        expList[1] = matchedFirstExp.val;
        for key, value in ipairs(matchedExpList.val) do
            expList[#expList+1] = value[2];
        end
        expList.node = NodeType.EXPLIST_NODE;
        return expList;
    end

    INDEX = indexCpy;

    return false
end

function NODE.EXP()
    local indexCpy = INDEX;

    local matchedExp = {val = nil};
    if SET(matchedExp, MATCH(NODE.LAMBDAFUNC)) then
        matchedExp.val.node = NodeType.LAMBDA_FUNC_NODE;
        return matchedExp.val;
    end
    INDEX = indexCpy;

    if SET(matchedExp, MATCH(NODE.UNOP, NODE.EXP)) then
        return {node = NodeType.UNEXP_NODE, unop = matchedExp.val[1], exp = matchedExp.val[2]};
    end
    INDEX = indexCpy;

    local matchedOp = {val = nil};
    if SET(matchedExp, MATCH(NODE.VALUE)) and SET(matchedOp, OPTIONAL(INDEX, NODE.BINOP, NODE.EXP)) then
        local op = nil;
        if #matchedOp.val > 0 then
            op = {node = NodeType.BINEXP_NODE, binop = matchedOp.val[1], term = matchedOp.val[2]};
        end
        return {node = NodeType.EVALUABLE_NODE, exp = matchedExp.val, op = op;};
    end
    INDEX = indexCpy;

    return false
end

function NODE.VALUE()
    local indexCpy = INDEX;

    local matchedValue = {val = nil};
    if SET(matchedValue, MATCH(TokenType.NIL_KEYWORD)) then
        return {type = 'nil', value = matchedValue.val.value};
    end 
    if SET(matchedValue, MATCH(TokenType.FALSE_KEYWORD)) then
        return {type = 'boolean', value = matchedValue.val.value}
    end 
    if SET(matchedValue, MATCH(TokenType.TRUE_KEYWORD)) then
        return {type = 'boolean', value = matchedValue.val.value}
    end
    if SET(matchedValue, MATCH(TokenType.NUMBER_VALUE)) then
        return {type = 'number', value = matchedValue.val.value}
    end 
    if SET(matchedValue, MATCH(TokenType.STRING_VALUE)) then
        return {type = 'string', value = matchedValue.val.value}
    end
    if SET(matchedValue, MATCH(TokenType.TRIPLE_POINT_MARK)) then
        return {type = 'table', value = matchedValue.val.value}
    end
    --[[if SET(matchedValue, MATCH(TokenType.FUNCTION_KEYWORD)) then
        return {type = 'function', value = matchedValue.val.value}
    end]]--
    if SET(matchedValue, MATCH(TokenType.NEW_KEYWORD, TokenType.IDENTIFIER, NODE.ARGS)) then
        return {type = matchedValue.val[2].value, node = NodeType.INSTANTIATION_NODE, id = matchedValue.val[2].value, args = matchedValue.val[3]};
    end
    INDEX = indexCpy;
    if SET(matchedValue, MATCH(NODE.TABLECONSTRUCTOR)) then
        return {type = 'table', value = matchedValue.val}
    end
    INDEX = indexCpy;
    if SET(matchedValue, MATCH(NODE.FUNCTIONCALL)) then
        return {type = 'functioncall', value = matchedValue.val}
    end
    INDEX = indexCpy;

    if SET(matchedValue, MATCH(NODE.VAR)) then
        return {type = 'var', value = matchedValue.val};
    end
    INDEX = indexCpy;
    
    if SET(matchedValue, MATCH(TokenType.LEFT_PARAN_MARK, NODE.EXP, TokenType.RIGHT_PARAN_MARK)) then
        return {node = NodeType.PARAN_EXP_NODE, exp = matchedValue.val[2]};
    end
    INDEX = indexCpy;

    return false
end

function NODE.INDEX()
    local indexCpy = INDEX;

    local matchedValue = {val = nil};
    if SET(matchedValue, MATCH(TokenType.LEFT_SQR_BRACKET_MARK, NODE.EXP, TokenType.RIGHT_SQR_BRACKET_MARK)) then
        return {node = NodeType.BRACKET_INDEX_NODE, val = matchedValue.val[2]};
    end
    INDEX = indexCpy;

    if SET(matchedValue, MATCH(TokenType.POINT_MARK, TokenType.IDENTIFIER)) then
        return {node = NodeType.POINT_INDEX_NODE, id = matchedValue.val[2].value};
    end
    INDEX = indexCpy;

    return false
end

function NODE.PREFIX()
    local indexCpy = INDEX;

    local matchedValue = {val = nil};
    if SET(matchedValue, MATCH(TokenType.LEFT_PARAN_MARK, NODE.EXP, TokenType.RIGHT_PARAN_MARK)) then
        return {node = NodeType.EXP_NODE, exp = matchedValue.val[2]};
    end
    INDEX = indexCpy;

    if SET(matchedValue, MATCH(TokenType.IDENTIFIER)) then
        return matchedValue.val.value;
    end
    INDEX = indexCpy;

    return false
end

function NODE.SUFFIX()
    local indexCpy = INDEX;

    local matchedSuffix = {val = nil};
    if SET(matchedSuffix, MATCH(NODE.CALL)) then
        return {node = NodeType.CALL_NODE, call = matchedSuffix.val};
    end
    INDEX = indexCpy;

    if SET(matchedSuffix, MATCH(NODE.INDEX)) then
        return matchedSuffix.val;
    end
    INDEX = indexCpy;

    return false
end

function NODE.CALL()
    local indexCpy = INDEX;

    local matchedCall = {val = nil};
    if SET(matchedCall, MATCH(NODE.ARGS)) then
        return {node = NodeType.ARGS_NODE, args = matchedCall.val};
    end
    INDEX = indexCpy;

    if SET(matchedCall, MATCH(TokenType.COLON_OPERATOR, TokenType.IDENTIFIER, NODE.ARGS)) then
        return {node = NodeType.INDEX_CALL_NODE, id = matchedCall.val[2], args = matchedCall.val[3]};
    end
    INDEX = indexCpy;

    return false
end

function NODE.FUNCTIONCALL()
    local indexCpy = INDEX;

    local matchedPrefix = {val = nil};
    local matchedSuffixList = {val = nil};
    local matchedCall = {val = nil};
    if SET(matchedPrefix, MATCH(NODE.PREFIX)) and 
    SET(matchedSuffixList, OPTIONAL_MULTIPLE_LEAVE_LAST(INDEX, NODE.SUFFIX)) and 
    SET(matchedCall, MATCH(NODE.CALL)) then
        return {
            node = NodeType.FUNCTION_CALL_NODE,
            prefix = matchedPrefix.val,
            suffix = matchedSuffixList.val,
            call = matchedCall.val
        };
    end

    INDEX = indexCpy;
    return false;
end

function NODE.ARGS()
    local indexCpy = INDEX;

    local matchedArgs = {val = nil};
    if MATCH(TokenType.LEFT_PARAN_MARK) and SET(matchedArgs, OPTIONAL(INDEX, NODE.EXPLIST)) and MATCH(TokenType.RIGHT_PARAN_MARK) then
        if #matchedArgs.val < 0 then
            matchedArgs.val = nil;
        end
        return matchedArgs.val;
    end
    INDEX = indexCpy;

    if SET(matchedArgs, MATCH(NODE.TABLECONSTRUCTOR)) then
        return {[1] = matchedArgs.val};
    end
    INDEX = indexCpy;

    if SET(matchedArgs, MATCH(TokenType.STRING_VALUE)) then
        return {[1] = matchedArgs.val.value};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.FUNCTIONDEF()
    local indexCpy = INDEX;

    local matchedFuncBody = {val = nil};
    if SET(matchedFuncBody, MATCH(TokenType.FUNCTION_KEYWORD, NODE.FUNCBODY)) then
        return {
            node = NodeType.FUNCTION_DECLARATION_NODE,
            id = matchedFuncBody.val[2].id,
            parlist = matchedFuncBody.val[2].parlist,
            type = matchedFuncBody.val[2].type,
            block = matchedFuncBody.val[2].block
        };
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LAMBDAFUNC()
    local indexCpy = INDEX;

    local matchedFuncBody = {val = nil};
    if SET(matchedFuncBody, MATCH(TokenType.FUNCTION_KEYWORD, NODE.FUNCBODY)) then
        return {
            parlist = matchedFuncBody.val[2].parlist,
            type = 'function',
            returnType = matchedFuncBody.val[2].type,
            block = matchedFuncBody.val[2].block
        };
    end
    INDEX = indexCpy;

    return false;
end

function NODE.FUNCBODY()
    local indexCpy = INDEX;

    local matchedParlist = {val = nil};
    local matchedType = {val = nil};
    local matchedBlock = {val = nil};
    if MATCH(TokenType.LEFT_PARAN_MARK) and SET(matchedParlist, OPTIONAL(INDEX, NODE.PARLIST)) and MATCH(TokenType.RIGHT_PARAN_MARK) and 
            utils.makeTrue(
                SET(matchedType, MATCH(TokenType.ARROW_OPERATOR, TokenType.IDENTIFIER)) or
                SET(matchedType, MATCH(TokenType.ARROW_OPERATOR, TokenType.ANY_KEYWORD))
            )
        and SET(matchedBlock, MATCH(NODE.BLOCK)) and MATCH(TokenType.END_KEYWORD) then

        local type = nil;
        if matchedType.val then
            type = matchedType.val[2].value;
        end
        return {parlist = matchedParlist.val, type = type, block = matchedBlock.val};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.PARLIST()
    local indexCpy = INDEX;
    
    local matchedNameList = {val = nil};
    local matchedTriplePoint = {val = nil};
    if SET(matchedNameList, MATCH(NODE.NAMELIST)) and 
    SET(matchedTriplePoint, OPTIONAL(INDEX, TokenType.COMMA_MARK, TokenType.TRIPLE_POINT_MARK)) then
        local isTriple = nil;
        if #matchedTriplePoint.val > 0 then
            isTriple = true;
        end
        return {namelist = matchedNameList.val, isTriple = isTriple};
    end
    INDEX = indexCpy;

    if MATCH(TokenType.TRIPLE_POINT_MARK) then
        return true;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.TABLECONSTRUCTOR()
    local indexCpy = INDEX;

    if MATCH(TokenType.LEFT_BRACE_MARK) and OPTIONAL(INDEX, NODE.FIELDLIST) and MATCH(TokenType.RIGHT_BRACE_MARK) then
        return true;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.FIELDLIST()
    local indexCpy = INDEX;
    
    if MATCH(NODE.FIELD) and OPTIONAL_MULTIPLE(INDEX, NODE.FIELDSEP, NODE.FIELD) and OPTIONAL(INDEX, NODE.FIELDSEP) then
        return true;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.FIELD()
    local indexCpy = INDEX;
    if MATCH(TokenType.LEFT_SQR_BRACKET_MARK, NODE.EXP, TokenType.RIGHT_SQR_BRACKET_MARK, TokenType.ASSIGN_OPERATOR, NODE.EXP) then
        return true;
    end
    INDEX = indexCpy;

    if MATCH(NODE.NAME, TokenType.ASSIGN_OPERATOR, NODE.EXP) then
        return true;
    end
    INDEX = indexCpy;

    if MATCH(NODE.EXP) then
        return true;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.FIELDSEP()
    local indexCpy = INDEX;

    if MATCH(TokenType.COMMA_MARK) then
        return true;
    end
    INDEX = indexCpy;

    if MATCH(TokenType.SEMICOLON_MARK) then
        return true;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.BINOP()
    local indexCpy = INDEX;

    local matchedOp = {val = nil};
    if SET(matchedOp, MATCH(TokenType.PLUS_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.MINUS_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.STAR_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.SLASH_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.DOUBLE_SLASH_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.CARET_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.PERCENT_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.AND_KEYWORD)) or 
       SET(matchedOp, MATCH(TokenType.TILDE_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.DOUBLE_POINT_MARK)) or 
       SET(matchedOp, MATCH(TokenType.LESS_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.LESS_OR_EQUAL_OPERATOR)) or
       SET(matchedOp, MATCH(TokenType.MORE_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.MORE_OR_EQUAL_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.EQUALS_OPERATOR)) or
       SET(matchedOp, MATCH(TokenType.NOT_EQUALS_OPERATOR)) or 
       SET(matchedOp, MATCH(TokenType.AND_KEYWORD)) or 
       SET(matchedOp, MATCH(TokenType.OR_KEYWORD)) then
        return {node = NodeType.BINOP_NODE, symbol = matchedOp.val.tokenType};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.UNOP()
    local indexCpy = INDEX;

    local matchedOp = {val = nil};
    if SET(matchedOp, MATCH(TokenType.MINUS_OPERATOR)) or 
    SET(matchedOp, MATCH(TokenType.NOT_KEYWORD)) or 
    SET(matchedOp, MATCH(TokenType.HASH_OPERATOR)) or 
    SET(matchedOp, MATCH(TokenType.TILDE_OPERATOR)) then
        return {node = NodeType.UNOP_NODE, symbol = matchedOp.val};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_NAMELIST()
    local indexCpy = INDEX;

    local fistNameMatched = {val = nil};
    local nameListMatched = {val = nil};
    if SET(fistNameMatched, MATCH(TokenType.LEFT_PARAN_MARK, NODE.LOGIC_NAME)) and
    SET(nameListMatched, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.LOGIC_NAME)) and
    MATCH(TokenType.RIGHT_PARAN_MARK) then
        local nameList = {[1] = fistNameMatched.val[2]};
        for index, value in ipairs(nameListMatched.val) do
            nameList[#nameList+1] = value[2];
        end
        return nameList;
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_NAME()
    local indexCpy = INDEX;

    local matchedId = {val = nil};
    local argType = {val = nil};
    if SET(matchedId, MATCH(TokenType.IDENTIFIER)) then
        return { node = NodeType.LOGIC_NAME_NODE, id = matchedId.val.value };
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_FUNC()
    local indexCpy = INDEX;

    local matchedFirstVar = {val = nil};
    local matchedVarList = {val = nil};
    local matchedStats = {val = nil};
    if SET(matchedFirstVar, MATCH(TokenType.LEFT_PARAN_MARK, NODE.LOGIC_VALUE)) and
    SET(matchedVarList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.LOGIC_VALUE)) and
    MATCH(TokenType.RIGHT_PARAN_MARK) and
    SET(matchedStats, OPTIONAL_MULTIPLE(INDEX, NODE.LOGIC_STAT)) and
    MATCH(TokenType.END_KEYWORD) then
        local vars = {[1] = matchedFirstVar.val[2]};
        for index, var in ipairs(matchedVarList.val) do
            vars[#vars + 1] = var[2];
        end
        return { args = vars, stats = matchedStats.val};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_TABLE()
    local indexCpy = INDEX;

    if MATCH(TokenType.LEFT_BRACE_MARK, TokenType.RIGHT_BRACE_MARK) then
        return { node = NodeType.LOGIC_TABLE_NODE };
    end
    INDEX = indexCpy;

    local matchedFirstHead = {val = nil};
    local matchedHeadList = {val = nil};
    local matchedTail = {val = nil};
    if SET(matchedFirstHead, MATCH(TokenType.LEFT_BRACE_MARK, NODE.LOGIC_VALUE)) and
    SET(matchedHeadList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.LOGIC_VALUE)) and
    SET(matchedTail, OPTIONAL(INDEX, TokenType.CONCATENATION_OPERATOR, NODE.LOGIC_VALUE)) and
    MATCH(TokenType.RIGHT_BRACE_MARK) then
        local head = { [1] = matchedFirstHead.val[2] };
        for index, value in ipairs(matchedHeadList.val) do
            head[#head+1] = value[2];
        end
        return { node = NodeType.LOGIC_TABLE_NODE, head = head, tail = matchedTail.val[2] };
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_VALUE()
    local indexCpy = INDEX;

    local matchedValue = {val = nil};
    if SET(matchedValue, MATCH(TokenType.LEFT_PARAN_MARK, NODE.LOGIC_EXP, TokenType.RIGHT_PARAN_MARK)) then
        return { paranExp = true, innerExp = matchedValue.val[2]};
    end
    INDEX = indexCpy;

    matchedValue = {val = nil};
    if SET(matchedValue, MATCH(NODE.LOGIC_TABLE)) then
        return matchedValue.val;
    end

    if SET(matchedValue, MATCH(TokenType.IDENTIFIER)) then
        return { node = NodeType.LOGIC_IDENTIFIER_NODE, id = matchedValue.val.value};
    end

    if SET(matchedValue, MATCH(TokenType.NUMBER_VALUE)) then
        return { node = NodeType.VALUE_NODE, value = matchedValue.val.value };
    end

    if SET(matchedValue, MATCH(TokenType.STRING_VALUE)) then
        return { node = NodeType.VALUE_NODE, value = matchedValue.val.value };
    end

    return false;
end

function NODE.LOGIC_FUNCTION_CALL()
    local indexCpy = INDEX;

    local matchedId = {val = nil};
    local matchedArgList = {val = nil};
    if SET(matchedId, MATCH(TokenType.IDENTIFIER, TokenType.LEFT_PARAN_MARK, NODE.LOGIC_VALUE)) and
    SET(matchedArgList, OPTIONAL_MULTIPLE(INDEX, TokenType.COMMA_MARK, NODE.LOGIC_VALUE)) and
    MATCH(TokenType.RIGHT_PARAN_MARK) then
        local args = {[1] = matchedId.val[3]};
        for index, arg in ipairs(matchedArgList.val) do
            args[#args+1] = arg[2];
        end
        local is_inbuilt = nil;
        if matchedId.val[1].value == 'is_list' or matchedId.val[1].value == 'atom' then
            is_inbuilt = true;
        end
        return {args = args, id = matchedId.val[1].value, node = NodeType.LOGIC_FUNCTION_CALL_NODE, is_inbuilt = is_inbuilt};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_STAT()
    local indexCpy = INDEX;
    
    local matchedVal = {val = nil};
    if MATCH(TokenType.SEMICOLON_MARK) then
        return {};
    end
    INDEX = indexCpy;

    if SET(matchedVal, MATCH(NODE.LOGIC_FUNCTION_CALL)) then
        return matchedVal.val;
    end
    INDEX = indexCpy;

    if SET(matchedVal, MATCH(NODE.LOGIC_VALUE, TokenType.ASSIGN_OPERATOR, NODE.LOGIC_VALUE)) then
        return {left = matchedVal.val[1], right = matchedVal.val[3], node = NodeType.LOGIC_UNIFY_NODE};
    end
    INDEX = indexCpy;

    if SET(matchedVal, MATCH(TokenType.IDENTIFIER, TokenType.ARROW_OPERATOR, NODE.LOGIC_EXP)) then
        return {left = matchedVal.val[1].value, right = matchedVal.val[3], node = NodeType.LOGIC_ASSIGN_NODE}
    end

    if SET(matchedVal, MATCH(NODE.LOGIC_EXP, NODE.LOGIC_CHECKS, NODE.LOGIC_EXP)) then
        return {left = matchedVal.val[1], check = matchedVal.val[2], right = matchedVal.val[3], node=NodeType.LOGIC_CHECK_NODE};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_CHECKS()
    local matchedCheck = {val = nil};
    if SET(matchedCheck, MATCH(TokenType.EQUALS_OPERATOR)) or
    SET(matchedCheck, MATCH(TokenType.NOT_EQUALS_OPERATOR)) or
    SET(matchedCheck, MATCH(TokenType.MORE_OPERATOR)) or
    SET(matchedCheck, MATCH(TokenType.LESS_OPERATOR)) or
    SET(matchedCheck, MATCH(TokenType.LESS_OR_EQUAL_OPERATOR)) or
    SET(matchedCheck, MATCH(TokenType.MORE_OR_EQUAL_OPERATOR)) then
        return matchedCheck.val.tokenType;
    end
    return false;
end

function NODE.LOGIC_EXP()
    local indexCpy = INDEX;

    local matchedValue = {val = nil};
    local matchedOps = {val = nil};
    if SET(matchedValue, MATCH(NODE.LOGIC_VALUE)) and SET(matchedOps, OPTIONAL(INDEX, NODE.LOGIC_BINOP, NODE.LOGIC_EXP)) then
        local binop, exp = nil, nil;
        if matchedOps.val then
            binop = matchedOps.val[1];
            exp = matchedOps.val[2];
        end
        if matchedValue.val.paranExp then
            matchedValue.val.exp = exp;
            matchedValue.val.binop = binop;
            return matchedValue.val;
        end
        return { value = matchedValue.val, binop = binop, exp = exp};
    end
    INDEX = indexCpy;

    return false;
end

function NODE.LOGIC_BINOP()
    local matchedOp = {val = nil};
    if SET(matchedOp, MATCH(TokenType.PLUS_OPERATOR)) or
    SET(matchedOp, MATCH(TokenType.MINUS_OPERATOR)) or
    SET(matchedOp, MATCH(TokenType.SLASH_OPERATOR)) or
    SET(matchedOp, MATCH(TokenType.STAR_OPERATOR)) or
    SET(matchedOp, MATCH(TokenType.PERCENT_OPERATOR))
    then
        return matchedOp.val.tokenType;
    end
end

function Parser.parse(lexems)
    LEXEMS = lexems;
    INDEX = 1;
    return NODE.CHUNK();
end

return Parser;