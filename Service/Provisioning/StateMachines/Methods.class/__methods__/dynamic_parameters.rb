#
#
module ManageIQ
  module Automate
    module Service
      module Provisioning
        module StateMachines
          class DynamicParameters
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              @handle.log('info', "dynamic_parameters starting ")
              @stp_task = @handle.root["service_template_provision_task"]
              raise ArgumentError, "service_template_provision_task not found" unless @stp_task
              @handle.log('info', "service_template_provision_task: #{@stp_task.inspect}")
              prov_task, task_type = get_target_task(@stp_task)
              @handle.log('info', "prov_task: #{prov_task.inspect} task_type: #{task_type}")
              hash = fetch_dynamic(prov_task, task_type)
              set_dynamic(hash, :option, prov_task, task_type)
            end

            private
            def fetch_dynamic(task, task_type)
              task_type == "service" ? fetch_from_service_dialogs(task.options[:dialog]) :
                fetch_from_provision_task(task.options) 
            end
            
            def fetch_from_provision_task(original_hash)
              @handle.log('info', "fetch_from_provision_task starting: original_hash #{original_hash.inspect}")
              hash = {}
              original_hash.each do |key, value|
                if /^lookup_(?<name>.*)/i =~ key
                  hash[name] = get_value(value)
                end
              end
              @handle.log('info', "fetch_from_provision_task returning: hash #{hash.inspect}")
              hash
            end

            def fetch_from_service_dialogs(original_hash)
              @handle.log('info', "fetch_from_service_dialogs starting: original_hash #{original_hash.inspect}")
              hash = {}
              original_hash.each do |key, value|
                if /^dialog_lookup_(?<name>.*)/i =~ key
                  hash["dialog_#{name}"] = get_value(value)
                end
              end
              @handle.log('info', "fetch_from_service_dialogs returning: hash #{hash.inspect}")
              hash
            end
            
            def set_dynamic(hash, where, task, task_type)
              case where
              when :option
              @handle.log('info', "set_dynamic setting: hash: #{hash.inspect} task: #{task.inspect}")
                if task_type == "service"
                  hash.each { |key, value| task.set_dialog_option(key, value) }
                else
                  hash.each { |key, value| task.set_option(key, value) }
                end
              else
                raise "Invalid #{where} when setting dynamic parameters"
              end
            end

            # item_1_option_name
            # item_1_method_method_name
            def get_value(value)
              if /^item_(?<index>\d*)_(?<where>[^_]*)_(?<name>.*)/i =~ value
                resolve_value(index.to_i, where, name)
              else
                { :value => value }
              end
            end

            def resolve_value(provision_index, where, name)
              @handle.log('info', "resolve_value: provision_index: #{provision_index.inspect} name: #{name}")
              task, task_type = fetch_source_provision_task(provision_index)
              case where
              when "option"
                if task_type == "service"
                  @handle.log('info', "resolve_value: service value: #{task.get_dialog_option(name)}")
                  task.get_dialog_option(name) 
                else  
                  @handle.log('info', "resolve_value: vm value: #{task.get_option(name.to_sym)}")
                  task.get_option(name.to_sym)
                end
              else
                raise "invalid #{where} in dynamic value field"
              end
            end

            def get_target_task(service_item_task, vm_index=0)
              if service_item_task.miq_request_tasks.empty?
                 raise ArgumentError, "Destination not found for #{service_item_task.id}" unless service_item_task.destination
                 return service_item_task.destination, "service"
              else
                return service_item_task.miq_request_tasks.first.miq_request_tasks[vm_index], "vm"
              end
            end

            def fetch_source_provision_task(provision_index)
              @handle.log('info', "fetch_source_provision_task starting provision_index: #{provision_index} ")
              service_tasks = @stp_task.miq_request.miq_request_tasks.select { |task| task.source_type == "ServiceTemplate" && !task.miq_request_task.nil?}
              item_task = service_tasks.detect { |task| task.provision_priority == provision_index - 1}
              @handle.log('info', "calling get_target_task: item_task: #{item_task.inspect} ")
              get_target_task(item_task)
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Service::Provisioning::StateMachines::DynamicParameters.new.main
end
