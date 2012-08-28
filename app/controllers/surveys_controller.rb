class SurveysController < ApplicationController

  def index
    @surveys = Survey.paginate(:page => params[:page], :per_page => 10)
  end
  
  def new
    @survey = Survey.new
  end

  def create
    @survey = Survey.new(params[:survey])

    if @survey.save
      redirect_to root_path
      flash[:notice] = t "flash.survey_created"
    else
      render :new
    end
  end

  def destroy
    survey = Survey.find(params[:id])
    survey.destroy
    flash[:notice] = t "flash.survey_deleted"
    redirect_to(surveys_path)
  end

  def backbone_create
    @survey = Survey.create(:name => "Untitled", :expiry_date => 7.days.from_now)

    if @survey.save
      redirect_to surveys_build_path(:id => @survey.id)
      flash[:notice] = t "flash.survey_created"
    else
      render :new
    end    
  end
end
