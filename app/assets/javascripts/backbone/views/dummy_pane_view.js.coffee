##= require ./question_factory
# Collection of dummy questions
class SurveyBuilder.Views.DummyPaneView extends Backbone.View
  el: "#dummy_pane"

  events:
    'add_dummy_sub_question': 'add_sub_question'

  initialize: (survey_model) ->
    @questions = []
    @survey_model = survey_model
    @add_survey_details(survey_model)
    ($(this.el).find("#dummy_questions")).sortable({update : this.reorder_questions})

  add_question: (type, model, parent) ->
    view = SurveyBuilder.Views.QuestionFactory.dummy_view_for(type, model)
    @questions.push(view)
    model.on('destroy', this.delete_question_view, this)
    this.render()

  insert_view_at_index: (view, index) ->
    if index == -1
      @questions.push(view)
    else
      @questions.splice(index + 1, 0, view)

  add_survey_details: (survey_model) ->
    template = $("#dummy_survey_details_template").html()
    @dummy_survey_details = new SurveyBuilder.Views.Dummies.SurveyDetailsView({ model: survey_model, template: template})

  render: ->
    ($(this.el).find("#dummy_survey_details").append(@dummy_survey_details.render().el)) 
    ($(this.el).find("#dummy_questions").append(question.render().el)) for question in @questions 
    return this

  unfocus_all: ->
    $(@dummy_survey_details.el).removeClass("active")
    question.unfocus() for question in @questions

  delete_question_view: (model) ->
    question = _(@questions).find((question) -> question.model == model )
    @questions = _(@questions).without(question)
    question.remove()

  reorder_questions: (event, ui) =>
    last_order_number = @survey_model.next_order_number()
    _(@questions).each (question) =>
      index = $(question.el).index()
      question.model.set({order_number: last_order_number + index + 1})
    @questions = _(@questions).sortBy (question) ->
      question.model.get('order_number')

  add_sub_question: (event, sub_question_model) =>
    template = $('#dummy_single_line_question_template').html()
    question = new SurveyBuilder.Views.Dummies.QuestionView(sub_question_model, template)
    this.questions.push question
    this.render()
