module Postzord
  module Receiver
    class LocalBatch
      attr_reader :object, :recipient_user_ids, :users

      def initialize(object, recipient_user_ids)
        @object = object
        @recipient_user_ids = recipient_user_ids
        @users = User.where(:id => @recipient_user_ids)
      end

      def perform!
        if @object.respond_to?(:relayable?)
          receive_relayable
        else
          create_post_visibilities
        end
        notify_mentioned_users if @object.respond_to?(:mentions)

        # 09/27/11 this is slow
        #socket_to_users if @object.respond_to?(:socket_to_user)
        notify_users
      end

      # NOTE(copied over from receiver public)
      # @return [Object]
      def receive_relayable
        if @object.parent.author.local?
          # receive relayable object only for the owner of the parent object
          @object.receive(@object.parent.author.owner)
        end
        @object
      end

      # Batch import post visibilities for the recipients of the given @object
      # @note performs a bulk insert into mySQL
      # @return [void]
      def create_post_visibilities
        contacts = Contact.where(:user_id => @recipient_user_ids, :person_id => @object.author_id)
        PostVisibility.batch_import(contacts, object)
      end

      # Notify any mentioned users within the @object's text
      # @return [void]
      def notify_mentioned_users
        @object.mentions.each do |mention|
          mention.notify_recipient
        end
      end

      #NOTE(these methods should be in their own module, included in this class)

      # Issue websocket requests to all specified recipients
      # @return [void]
      def socket_to_users
        @users.each do |user|
          @object.socket_to_user(user)
        end
      end

      # Notify users of the new object
      # return [void]
      def notify_users
        return unless @object.respond_to?(:notification_type)
        @users.each do |user|
          Notification.notify(user, @object, @object.author)
        end
      end
    end
  end
end
