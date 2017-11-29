class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def transform
    if (transformer_params[:file] && transformer_params[:file].path.split('.').last == 'csv')
      @transformer = CsvTransformService.new(
        transformer_params[:file].path,
        transformer_params[:date],
        transformer_params[:removal_date]
      )
      @result = @transformer.result
      send_data @result.read, filename: 'result.zip'
    else
      redirect_to root_path, alert: 'Error! Please try again.'
    end
  end

  private

  def transformer_params
    @transformer_params ||= params.require(:transformer).permit(:file, :date, :removal_date)
  end
end
