module ApiMonitor
  # What can be checked right now, as opposed to what the recorded calls say: is the database answering, and is the
  # monitor itself recording.
  module LiveCheck
    Result = Data.define(:database_up, :database_ms, :recording, :stored_calls, :max_rows, :environment, :rails_version)

    module_function

    def call
      up, milliseconds = database

      Result.new(database_up: up, database_ms: milliseconds, recording: ApiMonitor.enabled?,
                 stored_calls: up ? ApiRequest.count : nil, max_rows: ApiMonitor.settings.max_rows,
                 environment: Rails.env, rails_version: Rails.version)
    end

    # [answered?, how long it took in milliseconds]; a database that does not answer is reported, not raised.
    def database
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      up = ActiveRecord::Base.connection.select_value("SELECT 1") == 1
      [ up, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2) ]
    rescue ActiveRecord::ActiveRecordError
      [ false, nil ]
    end
    private_class_method :database
  end
end
