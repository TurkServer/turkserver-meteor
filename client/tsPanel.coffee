

Template.turkserver.events =
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-tabs").slideToggle()

Template.tsAdmin.adminEnabled = ->
  Session.equals("admin", true)
