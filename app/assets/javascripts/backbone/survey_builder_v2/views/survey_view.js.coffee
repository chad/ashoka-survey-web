class SurveyBuilderV2.Views.SurveyView extends Backbone.View
  events:
    "click .survey-header": "toggleCollapse"
    "click .update-survey": "updateModel"

  initialize: (attributes) =>
    @model = new SurveyBuilderV2.Models.SurveyModel(attributes.survey)
    @model.on("change", @render)
    @template = SMT["v2_survey_builder/surveys/header"]
    @savingIndicator = new SurveyBuilderV2.Views.SavingIndicatorView

  getEditableView: => this.$el.find(".survey-header-edit")

  toggleCollapse: =>
    @getEditableView().toggle('slow')

  render: =>
    this.$el.html(@template(@model.attributes))
    return this

  updateModel: =>
    name = @getEditableView().find("input[name=name]").val()
    description = @getEditableView().find("textarea[name=description]").val()
    @savingIndicator.show()
    @model.save({ name: name, description: description },
      success: @handleUpdateSuccess, error: @handleUpdateError)

  handleUpdateSuccess: (model, response, options) =>
    @savingIndicator.hide()
    @model.unset("errors")

  handleUpdateError: (model, response, options) =>
    @savingIndicator.error()
    @model.set(JSON.parse(response.responseText))
    @toggleCollapse()
