class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
  end

  def transform
    @transformer = CsvTransformService.new(transformer_params[:file].path, transformer_params[:date])
    @result = @transformer.result

    send_data @result, filename: "result.csv"
  end

  private

  def transformer_params
    @transformer_params ||= params.require(:transformer).permit(:file, :date)
  end
end
