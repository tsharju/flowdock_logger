defmodule Logger.Backends.Flowdock do

  use GenEvent

  def init(_) do
    if user = Process.whereis(:user) do
      Process.group_leader(self, user)
      conf = configure()
      {:ok, conf}
    else
      {:error, :ignore}
    end
  end

  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end
  
  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, endpoint: endpoint} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(endpoint, level, msg, ts, md, state)
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
    source = Keyword.get(env, :source)
    from_address = Keyword.get(env, :from_address)
    subject = Keyword.get(env, :subject)
    from_name = Keyword.get(env, :from_name, to_string(Node.self))
    project = Keyword.get(env, :project)
    tags = Keyword.get(env, :tags)

    endpoint = Keyword.get(env, :endpoint, :chat)
    
    %{format: format, level: level, metadata: metadata, api_token: api_token,
      source: source, subject: subject, from_name: from_name, project: project,
      tags: tags, from_address: from_address, endpoint: endpoint}
  end
  
  defp log_event(:inbox, level, msg, ts, md, %{format: format, metadata: metadata} = state) do
    ansidata = Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))
    
    url = "https://api.flowdock.com/v1/messages/team_inbox/#{state.api_token}"
    headers = [{"Content-Type",  "application/json"}]
    
    payload = ~s(
      {
          "source": "#{state.source}",
          "from_address": "#{state.from_address}",
          "subject": "#{state.subject}",
          "content": "#{ansidata}",
          "from_name": "#{state.from_name}",
          "project": "#{state.project}",
          "tags": #{inspect state.tags}
      })
    
    {:ok, status_code, _resp_headers, client_ref} =
      :hackney.request(:post, url, headers, payload, [])
    
    if status_code == 200 do
      {:ok, _body} = :hackney.body(client_ref)      
    end
    
  end

  defp log_event(:chat, level, msg, ts, md, %{format: format, metadata: metadata} = state) do
    ansidata = Logger.Formatter.format(format, level, msg, ts, Dict.take(md, metadata))
    
    url = "https://api.flowdock.com/v1/messages/chat/#{state.api_token}"
    headers = [{"Content-Type",  "application/json"}]
    
    payload = ~s(
      {
          "content": "#{ansidata}",
          "external_user_name": "#{String.replace(state.project, " ", "_")}",
          "tags": #{inspect state.tags}
          
      })
    
    {:ok, status_code, _resp_headers, client_ref} =
      :hackney.request(:post, url, headers, payload, [])
    
    if status_code == 200 do
      {:ok, _body} = :hackney.body(client_ref)
    end
    
  end
  
end
