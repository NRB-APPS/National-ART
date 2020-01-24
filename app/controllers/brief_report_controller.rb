class BriefReportController < ApplicationController
	def index
	end
	
	def display

		year = params["report_year"]
		q_from = params["quarter_from"]
		q_to = params["quarter_to"]
		
		@quarter = "#{q_from} #{year}"
		@quart = "#{q_to} #{year}"

		@display_result = ReportingReportDesignResource.find(:all, :select => ["name,contents,description"],
			:conditions => ["description = ? or description = ?", @quarter,@quart])
		@results = @display_result.to_json

	 	render :layout => "report"
	end

	def bfrief_report

		
    	render :template => "/report/summarised_report", 
    	:layout => false

  	end
end
