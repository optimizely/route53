record_wait_time = 20
record_wait_tries = 10

action :create do
  require 'aws-sdk-core'

  def create_record(name, value, region, zone_id, record_type, ttl)
    @route53 ||= Aws::Route53::Client.new(region: region)
    Chef::Log.debug "Record for #{name} to #{value} of type #{record_type}"
    @route53.change_resource_record_sets(
      hosted_zone_id: zone_id,
      change_batch: {
        changes: [
          {
            action: 'UPSERT',
            resource_record_set: {
              name: name.strip,
              type: record_type,
              ttl: ttl,
              resource_records: [{ value: value.strip }],
            },
          },
        ],
      },
    )
  end

  count = 0
  while count <= record_wait_tries do
    begin
      create_record(new_resource.name, new_resource.value, new_resource.region, new_resource.zone_id, new_resource.type, new_resource.ttl)
    rescue Aws::Route53::Errors::PriorRequestNotComplete
      if count >= record_wait_tries
        Chef::Application.fatal("Too many retries waiting for record to complete")
      else
        Chef::Log.info("Waiting for another record to complete")
        sleep(record_wait_time)
        count += 1
      end
      next
    end
    break
  end
end

action :delete do
  require 'aws-sdk-core'

  def delete_record(name, region, zone_id, record_type)
    @route53 ||= Aws::Route53::Client.new(region: region)
    Chef::Log.debug "Deleting record for #{name} of type #{record_type}"
    begin
      @route53.change_resource_record_sets(
        hosted_zone_id: zone_id,
        change_batch: {
          changes: [
            {
              action: 'DELETE',
              resource_record_set: {
                name: name.strip,
                type: record_type
              },
            },
          ],
        },
      )
    rescue Aws::Route53::Errors::ServiceError
      Chef::Log.info "Tried to delete non-existent record #{name} of type #{record_type}"
    end
  end

  count = 0
  while count <= record_wait_tries do
    begin
      delete_record(new_resource.name, new_resource.region, new_resource.zone_id, new_resource.type)
    rescue Aws::Route53::Errors::PriorRequestNotComplete
      if count >= record_wait_tries
        Chef::Application.fatal("Too many retries waiting for record to complete")
      else
        Chef::Log.info("Waiting for another record to complete")
        sleep(record_wait_time)
        count += 1
      end
      next
    end
    break
  end
end
