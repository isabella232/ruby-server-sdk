
module LaunchDarkly
  module Impl
    # Event constructors are centralized here to avoid mistakes and repetitive logic.
    # The LDClient owns two instances of EventFactory: one that always embeds evaluation reasons
    # in the events (for when variation_detail is called) and one that doesn't.
    #
    # Note that these methods do not set the "creationDate" property, because in the Ruby client,
    # that is done by EventProcessor.add_event().
    class EventFactory
      def initialize(with_reasons)
        @with_reasons = with_reasons
      end

      def new_eval_event(flag, user, detail, default_value, prereq_of_flag = nil)
        add_experiment_data = is_experiment(flag, detail.reason)
        e = {
          kind: 'feature',
          key: flag[:key],
          user: user,
          variation: detail.variation_index,
          value: detail.value,
          default: default_value,
          version: flag[:version]
        }
        # the following properties are handled separately so we don't waste bandwidth on unused keys
        e[:trackEvents] = true if add_experiment_data || flag[:trackEvents]
        e[:debugEventsUntilDate] = flag[:debugEventsUntilDate] if flag[:debugEventsUntilDate]
        e[:prereqOf] = prereq_of_flag[:key] if !prereq_of_flag.nil?
        e[:reason] = detail.reason if add_experiment_data || @with_reasons
        e
      end

      def new_default_event(flag, user, default_value, reason)
        e = {
          kind: 'feature',
          key: flag[:key],
          user: user,
          value: default_value,
          default: default_value,
          version: flag[:version]
        }
        e[:trackEvents] = true if flag[:trackEvents]
        e[:debugEventsUntilDate] = flag[:debugEventsUntilDate] if flag[:debugEventsUntilDate]
        e[:reason] = reason if @with_reasons
        e
      end

      def new_unknown_flag_event(key, user, default_value, reason)
        e = {
          kind: 'feature',
          key: key,
          user: user,
          value: default_value,
          default: default_value
        }
        e[:reason] = reason if @with_reasons
        e
      end

      def new_identify_event(user)
        {
          kind: 'identify',
          key: user[:key],
          user: user
        }
      end

      def new_custom_event(event_name, user, data, metric_value)
        e = {
          kind: 'custom',
          key: event_name,
          user: user
        }
        e[:data] = data if !data.nil?
        e[:metricValue] = metric_value if !metric_value.nil?
        e
      end

      private

      def is_experiment(flag, reason)
        return false if !reason
        case reason[:kind]
        when 'RULE_MATCH'
          index = reason[:ruleIndex]
          if !index.nil?
            rules = flag[:rules] || []
            return index >= 0 && index < rules.length && rules[index][:trackEvents]
          end
        when 'FALLTHROUGH'
          return !!flag[:trackEventsFallthrough]
        end
        false
      end
    end
  end
end
