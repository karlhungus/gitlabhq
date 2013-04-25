class MergeRequestObserver < ActiveRecord::Observer
  cattr_accessor :current_user

  def after_create(merge_request)
    if merge_request.assignee && merge_request.assignee != current_user
      Notify.delay.new_merge_request_email(merge_request.id)
    end

    if merge_request.author_id
      create_event(merge_request, Event.determine_action(merge_request))
    end
  end

  def after_close(merge_request, transition)
    send_reassigned_email(merge_request) if merge_request.is_being_reassigned?

    Note.create_status_change_note(merge_request, merge_request.target_project, current_user, merge_request.state)
    create_event(merge_request, Event::CLOSED)
  end

  def after_reopen(merge_request, transition)
    send_reassigned_email(merge_request) if merge_request.is_being_reassigned?

    Note.create_status_change_note(merge_request, merge_request.target_project, current_user, merge_request.state)
    create_event(merge_request, Event::REOPENED)
  end

  def after_update(merge_request)
    send_reassigned_email(merge_request) if merge_request.is_being_reassigned?
  end


  def after_merge(merge_request, transition)
    # Since MR can be merged via sidekiq
    # to prevent event duplication do this check
    return true if merge_request.merge_event
    create_event(merge_request, Event::MERGED)
  end


  protected

  def send_reassigned_email(merge_request)
    recipients_ids = merge_request.assignee_id_was, merge_request.assignee_id
    recipients_ids.delete current_user.id

    recipients_ids.each do |recipient_id|
      Notify.delay.reassigned_merge_request_email(recipient_id, merge_request.id, merge_request.assignee_id_was)
    end
  end

  def create_event(merge_request, status)
    Event.create(
        project: merge_request.target_project,
        target_id: merge_request.id,
        target_type: merge_request.class.name,
        action: status,
        author_id: merge_request.author_id
    )
  end

end
