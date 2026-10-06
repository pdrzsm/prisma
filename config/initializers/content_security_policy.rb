# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Política restrita: tudo vem do próprio Prisma, sem CDN, script inline ou
# atributo style. Ao adicionar JavaScript (importmap), configure um nonce para
# script-src em vez de liberar 'unsafe-inline'.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.font_src        :self
    policy.img_src         :self, :data
    policy.object_src      :none
    policy.script_src      :self
    policy.style_src       :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end
end
