namespace :event do
  desc "Create index for events"
  task :create_index => :environment do
    Event.__elasticsearch__.create_index!
  end

  desc "Delete index for events"
  task :delete_index => :environment do
    Event.__elasticsearch__.delete_index!
  end

  desc "Refresh index for events"
  task :refresh_index => :environment do
    Event.__elasticsearch__.refresh_index!
  end

  desc 'Import all events'
  task :import => :environment do
    from_id = (ENV['FROM_ID'] || 1).to_i
    until_id = (ENV['UNTIL_ID'] || Event.maximum(:id)).to_i

    Event.import(from_id: from_id, until_id: until_id)
  end
end
