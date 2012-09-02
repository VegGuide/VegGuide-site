
  _isa = (value, type, desc) ->
    [ ok, type_desc ] = _matches_any_type value, type

    return if ok

    throw "#{desc} must be #{type_desc}"

  _matches_any_type = (value, types) ->
    types = [types] unless types instanceof Array

    desc = []
    for type in types
      if typeof type == "string"
        return [true] if typeof value == type
        push desc, type
      else
        return [true] if value instanceof type
        push desc, /function (\w+)\(/.exec( type.constructor )

    desc = _.map desc, (val) ->
      article = if /^[aeiou]/.test(isa) then "an" else "a"
      "#{article} #{val}"

    joined =
      if desc.length == 1
        desc[0]
      else if desc.length == 2
        "#{ desc[0] } or #{ desc[1] }"
      else
        last = desc.pop
        desc = desc.join(", ") + ", or #{last}"

    return [ false, desc ]
