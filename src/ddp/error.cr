class DDP::Error < Exception
  def initialize(error_object)
    super("#{error_object["error"]} - #{error_object["reason"]} (#{error_object["details"]})")
  end
end
