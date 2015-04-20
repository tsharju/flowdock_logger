defmodule Logger.Backends.Flowdock do

  use GenEvent

  def init(_) do
    if user = Process.whereis(:user) do
      Process.group_leader(self, user)
      {:ok, configure()}
    else
      {:error, :ignore}
    end
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end
  
  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  ## Internal

  defp configure() do
    env = Application.get_env(:logger, :flowdock, [])
    
    format = env
    |> Keyword.get(:format)
    |> Logger.Formatter.compile
    
    level = Keyword.get(env, :level)
    metadata = Keyword.get(env, :metadata, [])

    api_token = Keyword.get(env, :api_token)
    
    %{format: format, level: level, metadata: metadata, api_token: api_token}
  end
  
  defp log_event(level, msg, ts, md, %{format: format, metadata: metadata} = state) do
    ansidata = Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))

    url = "https://api.flowdock.com/v1/messages/team_inbox/#{state.api_token}"
    headers = [{"Content-Type",  "application/json"}]
    
    payload = ~s(
    {
      "source": "Spells Server",
      "from_address": "servers@ministryofgames.io",
      "subject": "Server Event",
      "content": "#{ansidata}",
      "from_name": "#{Node.self}",
      "project": "Spells",
      "tags": []
    })
    
    {:ok, status_code, _resp_headers, client_ref} =
      :hackney.request(:post, url, headers, payload, [])
    
    if status_code == 200 do
      {:ok, _body} = :hackney.body(client_ref)      
    end
  end
  
end
