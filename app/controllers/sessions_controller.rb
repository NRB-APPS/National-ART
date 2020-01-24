class SessionsController < GenericSessionsController

 def set_session_var
  session[params[:key]] = params[:value]
  render :text => true
 end
end
