require 'spec_helper'

describe Response do
  it { should validate_presence_of(:survey_id)}
  it { should validate_presence_of(:organization_id)}
  it { should validate_presence_of(:user_id)}

  it "doesn't allow changing back from complete to incomplete" do
    response = FactoryGirl.create(:response, :complete)
    response.status = Response::Status::INCOMPLETE
    response.should_not be_valid
  end

  context "scopes" do
    it "returns responses in the chronological order" do
      old_response = Timecop.freeze(5.days.ago) { FactoryGirl.create(:response)}
      new_response = Timecop.freeze(5.days.from_now) { FactoryGirl.create(:response)}
      Response.earliest_first.should == [old_response, new_response]
    end

    it "returns complete responses" do
      complete_response = FactoryGirl.create(:response, :status => "complete")
      incomplete_response = FactoryGirl.create(:response, :status => "incomplete")
      Response.completed.should == [complete_response]
    end

    context "created_between" do
      it "returns responses in a date range" do
        from, to = (10.days.ago), (5.days.ago)
        response_before_range = Timecop.freeze(15.days.ago) { FactoryGirl.create(:response) }
        response_within_range = Timecop.freeze(7.days.ago) { FactoryGirl.create(:response) }
        response_after_range = Timecop.freeze(2.days.ago) { FactoryGirl.create(:response) }
        Response.created_between(from, to).should == [response_within_range]
      end

      it "includes responses created at the from and to dates" do
        from, to = (Date.parse("2013/05/05")), (Date.parse("2013/05/10"))
        from_date_response = Timecop.freeze(from) { FactoryGirl.create(:response) }
        to_date_response = Timecop.freeze(to) { FactoryGirl.create(:response) }
        Response.created_between(from, to).should =~ [from_date_response, to_date_response]
      end
    end
  end

  context "callbacks" do
    it "sets the completed_at date when the state changes to complete" do
      response = FactoryGirl.create(:response, :incomplete)
      response.status = "complete"
      current_time = Time.zone.now
      Timecop.freeze(current_time) { response.save }
      response.reload.completed_at.to_i.should == current_time.to_i
    end

    it "doesn't set the completed_at date when the state isn't complete" do
      response = FactoryGirl.create(:response, :incomplete)
      response.status = "incomplete"
      response.save
      response.reload.completed_at.should be_nil
    end

    it "doesn't change the completed_at date when the state stays complete" do
      current_time = Time.zone.now
      response = Timecop.freeze(current_time) { FactoryGirl.create(:response, :complete) }
      response.status = "complete"
      response.save
      response.reload.completed_at.to_i.should == current_time.to_i
    end
  end

  it "merges the response status based on updated_at" do
    response = FactoryGirl.create :response, :organization_id => 1, :user_id => 1, :status => 'complete'
    response.merge_status({ :status => 'incomplete', :updated_at => 5.days.ago.to_s })
    response.should be_complete
    response.merge_status({ :status => 'incomplete', :updated_at => 5.days.from_now.to_s })
    response.should be_incomplete
  end

  it "doesn't require a user_id and organization_id if it's survey is public" do
    survey = FactoryGirl.create :survey, :public => true
    response = Response.new(:survey => survey)
    response.should be_valid
  end

  context "when finding the time of the last update" do
    it "looks through the `updated_at` for all its answers" do
      response = FactoryGirl.create :response, :updated_at => 2.days.from_now
      answer = FactoryGirl.create(:answer)
      response.answers << answer
      time = 5.days.from_now
      answer.update_attribute :updated_at, time
      response.last_update.to_i.should ==  time.to_i
    end

    it "looks at the response's `updated_at` as well" do
      time = 2.days.from_now
      response = FactoryGirl.create :response, :updated_at => time
      response.answers << FactoryGirl.create(:answer)
      response.last_update.to_i.should ==  time.to_i
    end

    it "doesn't complain if the response has no answers" do
      response = FactoryGirl.create :response
      expect { response.last_update }.not_to raise_error
    end
  end

  context "when marking a response incomplete" do
    it "marks the response incomplete" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 1, :status => 'validating')
      response.incomplete
      response.reload.should_not be_complete
    end

    it "marks response complete if it's validating" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 1, :status => 'validating')
      response.complete
      response.reload.should be_complete
    end

    it "returns whether a response is complete or not" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 1)
      response.validating
      response.reload.should be_validating
    end

    it "returns whether a response is incomplete or not" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 1)
      response.incomplete
      response.reload.should be_incomplete
    end

    it "only updates the status field and nothing else" do
      response = FactoryGirl.create(:response, :organization_id => 1, :user_id => 1)
      response.organization_id = 5
      response.incomplete
      response.complete
      response.validating
      response.reload.organization_id.should_not == 5
    end
  end

  context "when creating a valid response from params"  do
    let (:survey) { FactoryGirl.create(:survey) }
    let (:question) { FactoryGirl.create(:question, :finalized) }

    it "creates a response" do
      resp = FactoryGirl.build(:response, :survey_id => survey.id, :organization_id => 42, :user_id => 50)
      expect {
        resp.create_valid_response_from_params({ :answers_attributes => {} })
      }.to change { Response.count }.by 1
    end

    it "creates the nested answers" do
      resp = FactoryGirl.build(:response, :survey_id => survey.id, :organization_id => 42, :user_id => 50)
      answers_attributes = {'0' => {'content' => 'asdasd', 'question_id' => question.id}}
      expect {
        resp.create_valid_response_from_params({ :answers_attributes => answers_attributes })
      }.to change { Answer.count }.by 1
    end

    it "should not increase the response count if the answers are invalid" do
      question = FactoryGirl.create(:question, :finalized, :max_length => 2, :survey => survey)
      resp = FactoryGirl.build(:response, :survey_id => survey.id, :organization_id => 42, :user_id => 50)
      answers_attributes = {'0' => {'content' => 'abcd', 'question_id' => question.id}}
      expect {
        resp.create_valid_response_from_params({ :answers_attributes => answers_attributes })
      }.to_not change { Response.count }
    end

    it "should not increase the response count if an exception is thrown when saving the answers" do
      resp = FactoryGirl.build(:response, :survey_id => survey.id, :organization_id => 42, :user_id => 50)
      answers_attributes = {'0' => {'content' => 'abcd', 'question_id' => question.id}}
      original_update_attributes = resp.method(:update_attributes)
      resp.stub(:update_attributes) { |*args| original_update_attributes.call(*args) }
      resp.stub(:update_attributes).with(:answers_attributes => answers_attributes).and_raise(ActiveRecord::Rollback)
      expect {
        resp.create_valid_response_from_params({ :answers_attributes => answers_attributes })
      }.to_not change { Response.count }
    end

    context "return values" do
      it "returns true if valid response" do
        resp = FactoryGirl.build(:response, :survey_id => survey.id, :organization_id => 42, :user_id => 50)
        resp.create_valid_response_from_params({ :answers_attributes => {} }).should be_true
      end

      it "returns false for an invalid response" do
        resp = FactoryGirl.build(:response, :survey_id => survey.id)
        resp.create_valid_response_from_params({ :answers_attributes => {} }).should be_false
      end
    end

    it "updates the response_id for its answers' records" do
      record = FactoryGirl.create :record, :response_id => nil
      answers_attrs = { '0' => { :content => 'AnswerFoo', :question_id => question.id, :record_id => record.id } }
      resp = FactoryGirl.build(:response, :survey_id => survey.id, :user_id => 50, :organization_id => 42)
      resp.create_valid_response_from_params(:answers_attributes => answers_attrs)
      record.reload.response_id.should_not be_nil
      record.reload.response_id.should == resp.id
    end
  end

  context "when updating a valid response from params" do
    let(:response) { FactoryGirl.create(:response) }

    it "should return nil if no params are passed in" do
      response.update_valid_response_from_params(nil).should be_nil
    end

    it "doesn't change the response status if there isn't a param for it" do
      response = FactoryGirl.create(:response, :incomplete)
      response.update_valid_response_from_params(:comment => "foo")
      response.reload.should be_incomplete
    end

    context "when the status is changed from incomplete to complete" do
      it "doesn't change the response status if the answers are invalid" do
        response = FactoryGirl.create(:response, :incomplete)
        mandatory_question = FactoryGirl.create(:single_line_question, :mandatory, :finalized)
        answers_attributes = { "0" => { :question_id => mandatory_question.id, :content => ""}}
        response.update_valid_response_from_params(:status => Response::Status::COMPLETE, :answers_attributes => answers_attributes)
        response.reload.should be_incomplete
      end

      it "changes the response status if the answers are valid" do
        response = FactoryGirl.create(:response, :incomplete)
        question = FactoryGirl.create(:single_line_question, :mandatory, :finalized)
        answers_attributes = { "0" => { :question_id => question.id, :content => "Foo"}}
        response.update_valid_response_from_params(:status => Response::Status::COMPLETE, :answers_attributes => answers_attributes)
        response.reload.should be_complete
      end
    end


    it "updates the response's answers" do
      response = FactoryGirl.create(:response, :incomplete)
      question = FactoryGirl.create(:single_line_question, :finalized)
      answers_attributes = { "0" => { :question_id => question.id, :content => "Foo"}}
      response.update_valid_response_from_params(:status => Response::Status::COMPLETE, :answers_attributes => answers_attributes)
      response.reload.answers[0].content.should == "Foo"
    end

    it "updates the response" do
      response = FactoryGirl.create(:response, :incomplete)
      response.update_valid_response_from_params(:comment => "foo")
      response.reload.comment.should == "foo"
    end
  end

  context "#set" do
    it "sets the survey_id, user_id, organization_id and session_token" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.build(:response)
      response.set(survey.id, 5, 6, "foo")
      response.survey_id.should == survey.id
      response.user_id.should == 5
      response.organization_id.should == 6
      response.session_token.should == "foo"
    end
  end

  it "gets the questions that it contains answers for" do
    survey = FactoryGirl.create(:survey)
    response = FactoryGirl.build(:response, :survey_id => survey.id)
    response.questions.should == survey.questions
  end

  it "gets the public status of its survey" do
    survey = FactoryGirl.create(:survey, :public => true)
    response = FactoryGirl.build(:response, :survey_id => survey.id)
    response.survey_public?.should be_true
  end

  context "when updating answers" do
    it "selects only the new answers to update" do
      survey = FactoryGirl.create(:survey)
      response = FactoryGirl.create(:response, :survey => survey)
      question_1 = FactoryGirl.create(:question, :finalized, :survey_id => survey.id)
      question_2 = FactoryGirl.create(:question, :finalized, :survey_id => survey.id)
      answer_1 = FactoryGirl.create(:answer, :question_id => question_1.id, :updated_at => Time.now, :content => "older", :response_id => response.id)
      answer_2 = FactoryGirl.create(:answer, :question_id => question_2.id, :updated_at => 5.hours.from_now, :content => "newer", :response_id => response.id)
      answers_attributes = { '0' => {"question_id" => question_1.id, "updated_at" => 5.hours.from_now.to_s, "id" => answer_1.id, "content" => "newer"},
                             '1' => {"question_id" => question_2.id, "updated_at" => Time.now.to_s, "id" => answer_2.id, "content" => "older"}}
      selected_answers = response.select_new_answers(answers_attributes)
      selected_answers.keys.should == ['0']
    end
  end

  context "#update_answers" do
    it "takes answer params and updates the specific answers" do
      response = FactoryGirl.create :response
      answer = FactoryGirl.create :answer, :content => "ABCD", :response_id => response.id
      response.reload.update_answers({ '0' => {:content => 'XYZ', :id => answer.id}})
      answer.reload.content.should == 'XYZ'
    end

    it "clears the old answers" do
      response = FactoryGirl.create :response
      answer_1 = FactoryGirl.create :answer, :content => "ABCD", :response_id => response.id
      answer_2 = FactoryGirl.create :answer, :content => "DEF", :response_id => response.id
      response.reload.update_answers({ '0' => {:content => 'XYZ', :id => answer_1.id}})
      answer_2.reload.content.should be_blank
    end

    it "rolls back all DB changes if there's a single validation error" do
      response = FactoryGirl.create(:response, :complete)
      mandatory_question = FactoryGirl.create(:question, :finalized, :mandatory => true)
      answer_1 = FactoryGirl.create(:answer, :content => "ABCD", :response_id => response.id, :question_id => mandatory_question.id)
      answer_2 = FactoryGirl.create(:answer, :content => "DEF", :response_id => response.id)
      response.reload.update_answers({ '0' => {:content => '', :id => answer_1.id}})
      answer_1.reload.content.should == "ABCD"
      answer_2.reload.content.should == "DEF"
    end

    it "returns true if no params are passed in" do
      response = FactoryGirl.create :response
      response.update_answers(nil).should be_true
    end

    it "returns true for a successful save" do
      response = FactoryGirl.create :response
      answer = FactoryGirl.create :answer, :content => "ABCD", :response_id => response.id
      response.reload.update_answers({ '0' => {:content => 'XYZ', :id => answer.id}}).should be_true
    end
  end

  context "#to_json_with_answers_and_choices" do
    it "renders the answers" do
      response = (FactoryGirl.create :response_with_answers).reload
      response_json = JSON.parse(response.to_json_with_answers_and_choices)
      response_json.should have_key('answers')
      response_json['answers'].size.should == response.answers.size
    end

    it "renders the answers' image as base64 as well" do
      response = FactoryGirl.create(:response)
      photo_answer = FactoryGirl.create(:answer_with_image, :response => response)
      response.reload
      response_json = JSON.parse(response.to_json_with_answers_and_choices)
      response_json['answers'][0].should have_key('photo_in_base64')
      response_json['answers'][0]['photo_in_base64'].should == photo_answer.photo_in_base64
    end

    it "renders the answers' choices if any" do
      response = (FactoryGirl.create :response).reload
      response.answers << FactoryGirl.create(:answer_with_choices)
      response_json = JSON.parse(response.to_json_with_answers_and_choices)
      response_json['answers'][0].should have_key('choices')
      response_json['answers'][0]['choices'].size.should == response.answers[0].choices.size
    end
  end

  context "when fetching sorted answers" do
    let(:survey) {FactoryGirl.create(:survey)}
    let(:response) { FactoryGirl.create :response, :survey => survey }

    it "returns a sorted list of answers for all its first level questions" do
      question = FactoryGirl.create(:question, :finalized, :survey => survey, :order_number => 2)
      another_question = FactoryGirl.create(:question, :finalized, :survey => survey, :order_number => 1)
      answer = FactoryGirl.create(:answer, :response => response, :question => question)
      another_answer = FactoryGirl.create(:answer, :response => response, :question => another_question)
      response.sorted_answers.should == [another_answer, answer]
    end

    it "returns a sorted list of answers for all sub-questions of a category" do
      category = FactoryGirl.create(:category, :survey => survey)
      question = FactoryGirl.create(:question, :finalized, :survey => survey, :order_number => 2, :category => category)
      another_question = FactoryGirl.create(:question , :finalized, :survey => survey, :order_number => 1, :category => category)
      answer = FactoryGirl.create(:answer, :response => response, :question => question)
      another_answer = FactoryGirl.create(:answer, :response => response, :question => another_question)
      response.sorted_answers.should == [another_answer, answer]
    end

    it "returns a sorted list of answers for all sub-questions of an option" do
      radio_question = FactoryGirl.create(:radio_question, :finalized, :survey => survey)
      radio_answer = FactoryGirl.create(:answer, :response => response, :question => radio_question)

      option = FactoryGirl.create(:option, :question => radio_question)
      question = FactoryGirl.create(:question, :finalized, :survey => survey, :order_number => 2, :parent => option)
      another_question = FactoryGirl.create(:question , :finalized, :survey => survey, :order_number => 1, :parent => option)

      answer = FactoryGirl.create(:answer, :response => response, :question => question)
      another_answer = FactoryGirl.create(:answer, :response => response, :question => another_question)

      response.sorted_answers.should == [radio_answer, another_answer, answer]
    end
  end

  context 'when creating blank answers' do
    it "creates blank answers for each of its survey's questions" do
      survey = FactoryGirl.create :survey
      question = FactoryGirl.create :question, :survey => survey

      response = FactoryGirl.create :response, :survey => survey
      response.create_blank_answers

      question.answers.should_not be_nil
    end

    it "creates blank answers for each of its survey's categories" do
      survey = FactoryGirl.create :survey
      category = FactoryGirl.create :category, :survey => survey
      question = FactoryGirl.create :question, :survey => survey, :category => category

      response = FactoryGirl.create :response, :survey => survey
      response.create_blank_answers

      question.answers.should_not be_nil
    end

    it "creates blank answers with the correct response_id" do
      survey = FactoryGirl.create :survey
      question = FactoryGirl.create :question, :finalized, :survey => survey

      response = FactoryGirl.create :response, :survey => survey
      response.create_blank_answers

      question.answers[0].response_id.should == response.id
    end

    context "for its answers' records" do
      context "if the response_id is not set" do
        it "sets it to its own id" do
          response = FactoryGirl.create(:response)
          record = FactoryGirl.create(:record, :response_id => nil)
          response.answers << FactoryGirl.create(:answer, :record => record)
          response.update_records
          record.reload.response.should == response
        end
      end

      context "if the response_id is set" do
        it "doesn't change the response_id" do
          response = FactoryGirl.create :response
          record = FactoryGirl.create(:record, :response_id => 123)
          response.answers << FactoryGirl.create(:answer, :record => record)
          response.update_records
          record.reload.response_id.should == 123
        end
      end
    end
  end

  context 'when calculating the page size' do
    before(:each) { stub_const('Response::MAX_PAGE_SIZE', 50) }

    it "allows the passed in value if it is below MAX_PAGE_SIZE" do
      Response.page_size(10).should == 10
    end

    it "doesn't allow the passed in value if it is above MAX_PAGE_SIZE" do
      Response.page_size(51).should == 50
    end

    it "returns the MAX_PAGE_SIZE if nothing is passed in" do
      Response.page_size.should == 50
    end
  end
end
