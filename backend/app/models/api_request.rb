# One recorded call to the JSON API, with its payloads, for the admin's API monitor. Written once by
# ApiMonitor::Recorder and never edited; only the newest rows are kept (see prune!).
class ApiRequest < ApplicationRecord
  belongs_to :user, optional: true

  def self.prune!(keep:)
    cutoff = order(id: :desc).offset(keep).limit(1).pick(:id)
    cutoff ? where(id: ..cutoff).delete_all : 0
  end

  def readonly?
    super || persisted?
  end

  def status_class
    "#{status / 100}xx"
  end

  def server_error?
    status >= 500
  end

  def client_error?
    status.between?(400, 499)
  end
end
