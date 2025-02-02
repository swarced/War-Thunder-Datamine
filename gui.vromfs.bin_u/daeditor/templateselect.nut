from "%darg/ui_imports.nut" import *

let {showTemplateSelect, editorIsActive, showDebugButtons, selectedTemplatesGroup} = require("state.nut")
let {colors} = require("components/style.nut")
let txt = require("%darg/components/text.nut").dtext

let textButton = require("components/textButton.nut")
let nameFilter = require("components/nameFilter.nut")
let combobox = require("%darg/components/combobox.nut")
let scrollbar = require("%darg/components/scrollbar.nut")
let {mkTemplateTooltip} = require("components/templateHelp.nut")

let entity_editor = require("entity_editor")
let daEditor4 = require("daEditor4")
let {DE4_MODE_SELECT} = daEditor4

let selectedItem = Watched(null)
let filterText = Watched("")
let templatePostfixText = Watched("")

let scrollHandler = ScrollHandler()


let function scrollByName(text) {
  scrollHandler.scrollToChildren(function(desc) {
    return ("tpl_name" in desc) && desc.tpl_name.indexof(text)!=null
  }, 2, false, true)
}

let function scrollBySelection() {
  scrollHandler.scrollToChildren(function(desc) {
    return ("tpl_name" in desc) && desc.tpl_name==selectedItem.value
  }, 2, false, true)
}

let function doSelectTemplate(tpl_name) {
  selectedItem(tpl_name)
  if (selectedItem.value) {
    let finalTemplateName = selectedItem.value + templatePostfixText.value
    entity_editor.get_instance().selectEcsTemplate(finalTemplateName)
  }
}

let filter = nameFilter(filterText, {
  placeholder = "Filter by name"

  function onChange(text) {
    filterText(text)

    if (selectedItem.value && text.len()>0 && selectedItem.value.tolower().contains(text.tolower()))
      scrollBySelection()
    else if (text.len())
      scrollByName(text)
    else
      scrollBySelection()
  }

  function onEscape() {
    set_kb_focus(null)
  }
})

let templPostfix = nameFilter(templatePostfixText, {
  placeholder = "Template postfix"

  function onChange(text) {
    templatePostfixText(text)
  }

  function onEscape() {
    if (templatePostfixText.value != "")
      templatePostfixText("")
    else
      set_kb_focus(null)
  }
})

let templateTooltip = Watched(null)

let function listRow(tpl_name, idx) {
  let stateFlags = Watched(0)

  return function() {
    let isSelected = selectedItem.value == tpl_name

    local color
    if (isSelected) {
      color = colors.Active
    } else {
      color = (stateFlags.value & S_HOVER) ? colors.GridRowHover : colors.GridBg[idx % colors.GridBg.len()]
    }

    return {
      rendObj = ROBJ_SOLID
      size = [flex(), SIZE_TO_CONTENT]
      color = color
      behavior = Behaviors.Button
      tpl_name = tpl_name

      watch = stateFlags
      onHover = @(on) templateTooltip(on ? mkTemplateTooltip(tpl_name) : null)
      onClick = @() doSelectTemplate(tpl_name)
      onElemState = @(sf) stateFlags.update(sf & S_HOVER)

      children = {
        rendObj = ROBJ_DTEXT
        text = tpl_name
        margin = fsh(0.5)
      }
    }
  }
}

let selectedGroupTemplates = Computed(@() editorIsActive.value ? entity_editor.get_instance()?.getEcsTemplates(selectedTemplatesGroup.value) ?? [] : [])

let filteredTemplates = Computed(function() {
  let result = []
  foreach (tplName in selectedGroupTemplates.value) {
    if (filterText.value.len()==0 || tplName.tolower().contains(filterText.value.tolower())) {
      result.append(tplName)
    }
  }
  return result
})

let filteredTemplatesCount = Computed(@() filteredTemplates.value.len())
let selectedGroupTemplatesCount = Computed(@() selectedGroupTemplates.value.len())


local doRepeatValidateTemplates = @(idx) null
let function doValidateTemplates(idx) {
  const validateAfterName = ""
  local skipped = 0
  while (idx < selectedGroupTemplates.value.len()) {
    let tplName = selectedGroupTemplates.value[idx]
    if (tplName > validateAfterName) {
      vlog($"Validating template {tplName}...")
      selectedItem(tplName)
      scrollBySelection()
      gui_scene.resetTimeout(0.01, function() {
        doSelectTemplate(tplName)
        doRepeatValidateTemplates(idx+1)
      })
      return
    }
    vlog($"Skipping template {tplName}...")
    if (++skipped > 50) {
      selectedItem(tplName)
      scrollBySelection()
      gui_scene.resetTimeout(0.01, @() doRepeatValidateTemplates(idx+1))
      return
    }
    idx += 1
  }
  vlog("Validation complete")
}
doRepeatValidateTemplates = doValidateTemplates


let function dialogRoot() {
  let templatesGroups = entity_editor.get_instance().getEcsTemplatesGroups()

  let function listContent() {
    let rows = []
    let idx = 0
    foreach (tplName in filteredTemplates.value) {
      if (filterText.value.len()==0 || tplName.tolower().contains(filterText.value.tolower())) {
        rows.append(listRow(tplName, idx))
      }
    }

    return {
      watch = [filteredTemplates, selectedItem, filterText]
      size = [flex(), SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      children = rows
      behavior = Behaviors.Button
    }
  }

  let scrollList = scrollbar.makeVertScroll(listContent, {
    scrollHandler
    rootBase = class {
      size = flex()
      behavior = Behaviors.RecalcHandler
      function onRecalcLayout(initial) {
        if (initial) {
          scrollBySelection()
        }
      }
    }
  })


  let function doCancel() {
    showTemplateSelect(false)
    filterText("")
    daEditor4.setEditMode(DE4_MODE_SELECT)
  }


  return {
    size = [flex(), flex()]
    flow = FLOW_HORIZONTAL

    watch = [filteredTemplatesCount, selectedGroupTemplatesCount, showDebugButtons, templateTooltip]

    children = [
      {
        size = [sw(17), sh(75)]
        hplace = ALIGN_LEFT
        vplace = ALIGN_CENTER
        rendObj = ROBJ_SOLID
        color = colors.ControlBg
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        behavior = Behaviors.Button
        key = "template_select"
        padding = fsh(0.5)
        gap = fsh(0.5)

        children = [
          txt($"CREATE ENTITY ({filteredTemplatesCount.value}/{selectedGroupTemplatesCount.value})", {fontSize = hdpx(15) hplace = ALIGN_CENTER})
          {
            size = [flex(),fontH(100)]
            children = combobox(selectedTemplatesGroup, templatesGroups)
          }
          filter
          {
            size = flex()
            children = scrollList
          }
          templPostfix
          {
            flow = FLOW_HORIZONTAL
            size = [flex(), SIZE_TO_CONTENT]
            halign = ALIGN_CENTER
            valign = ALIGN_CENTER
            children = [
              textButton("Close", doCancel, {hotkeys=["^Esc"]})
              showDebugButtons.value ? textButton("Validate", @() doValidateTemplates(0), {boxStyle={normal={borderColor=Color(50,50,50,50)}} textStyle={normal={color=Color(80,80,80,80) fontSize=hdpx(12)}}}) : null
            ]
          }
        ]
      }
      {
        size = [sw(17), sh(60)]
        hplace = ALIGN_LEFT
        vplace = ALIGN_CENTER
        children = templateTooltip.value
      }
    ]
  }
}


return dialogRoot
