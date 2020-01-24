=begin
  Written by : Kenneth Kapundi
  Written on : 1st September 2015
  Purpose : Query inconsistencies in data and record them against associated validation rules
			for use by data quality monitoring dashboard

=end

def start(date)
	puts "Running data consistency checks for #{date}"
	ValidationRule.data_consistency_checks(date)
end

start(Date.today)
