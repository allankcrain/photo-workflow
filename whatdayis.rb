#!/usr/bin/env ruby
require 'date'
require 'optparse'

MONTH_S = 10   # Month of the first day of the photo year
DAY_S = 20     # Day of the first day of the photo year
YEAR_S = 2007  # Year on which I started taking pictures

# Default to today's date
dates = ARGV.length > 0 ? ARGV : [Date.today.iso8601]

# I can't think of a single reason why I'd pass this script multiple dates, but... It supports it.
dates.each do |argument|
  # Make a Date object of the command line argument, if possible
  begin
    target_date = Date.parse(argument);

    # Find the previous day-one for the current photo year and make a Date object.
    current_year = target_date.month > MONTH_S ||
                  (target_date.month == MONTH_S && target_date.day >= DAY_S) ?
      target_date.year : target_date.year - 1
    previous_birthday = Date.new(current_year, MONTH_S, DAY_S)

    # Get the number of days between the previous day-one and the target date
    days = (target_date - previous_birthday).to_i() + 1 # Plus 1 because we one-index photo days

    # Get the number of days total I've been taking photos, because that's neat to know
    days_total = (target_date - Date.new(YEAR_S, MONTH_S, DAY_S)).to_i() + 1

    puts("#{dates.length > 1 ? target_date.strftime('%Y-%m-%d: ') : ''}Day #{days} (absolute: #{days_total})")

  # Handle if the date parse dies.
  rescue
    puts("I don't know what a '#{argument}' is, but it doesn't look like a date to me.")
  end
end
