defmodule NotificationsStorer do
  use Agent

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def get_notifications() do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def add_notification(notification) do
    Agent.update(__MODULE__, fn state -> [notification | state] end)
  end
end
