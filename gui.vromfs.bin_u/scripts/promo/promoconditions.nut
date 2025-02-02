let visibleConditionsList = {
  isInClan = @() ::is_in_clan()
  isNotInClan = @() !::is_in_clan()
}

let function isVisibleByConditions(blk)
{
  let visibleConditions = blk?.visibleConditions
  if (visibleConditions == null)
    return true

  foreach (name in ::split(visibleConditions, "; "))
    if (!(visibleConditionsList?[name]?() ?? true))
      return false

  return true
}

return {
  isVisibleByConditions = isVisibleByConditions
}