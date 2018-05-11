angular.module 'mnoEnterpriseAngular'
  .controller('ProvisioningSubscriptionsCtrl', ($q, $state, $stateParams, toastr, MnoeOrganizations, MnoeProvisioning, MnoeConfig, MnoConfirm, PRICING_TYPES) ->

    vm = this
    vm.isLoading = true

    vm.goToSubscription = (subscription) ->
      $state.go('home.subscription', { id: subscription.id })

    vm.cancelSubscription = (subscription, i) ->
      modalOptions =
        headerText: 'mno_enterprise.templates.dashboard.provisioning.subscriptions.cancel_modal.title'
        bodyText: 'mno_enterprise.templates.dashboard.provisioning.subscriptions.cancel_modal.body'
        closeButtonText: 'mno_enterprise.templates.dashboard.provisioning.subscriptions.cancel_modal.no'
        actionButtonText: 'mno_enterprise.templates.dashboard.provisioning.subscriptions.cancel_modal.yes'
        actionCb: -> MnoeProvisioning.cancelSubscription(subscription).then(
          (response) ->
            angular.copy(response.subscription, vm.subscriptions[i])
          ->
            toastr.error('mno_enterprise.templates.dashboard.provisioning.subscriptions.cancel_error')
        )
        type: 'danger'

      MnoConfirm.showModal(modalOptions)

    orgPromise = MnoeOrganizations.get()
    subPromise = MnoeProvisioning.getSubscriptions()

    $q.all({organization: orgPromise, subscriptions: subPromise}).then(
      (response) ->
        vm.orgCurrency = response.organization.organization?.billing_currency || MnoeConfig.marketplaceCurrency()

        # If a subscription doesn't contains a pricing for the org currency, a warning message is displayed
        vm.displayCurrencyWarning = not _.every(response.subscriptions, (subscription) ->
          currencies = _.map(subscription?.product_pricing?.prices, 'currency')
          _.includes(currencies, vm.orgCurrency) || (subscription?.product_pricing?.pricing_type in PRICING_TYPES['unpriced'])
        )
        vm.subscriptions = response.subscriptions
    ).finally(-> vm.isLoading = false)

    vm.displayInfoTooltip = (subscription) ->
      return subscription.status == 'aborted'

    vm.showEditAction = (subscription, editAction) ->
      return false unless subscription.available_actions
      editAction in subscription.available_actions

    vm.editSubscription = (subscription, editAction) ->
      MnoeProvisioning.setSubscription({})
      params = {subscriptionId: subscription.id, editAction: editAction}
      switch editAction.toLowerCase( )
        when 'change'
          $state.go('home.provisioning.order', params)
        else
          $state.go('home.provisioning.additional_details', params)

    return
  )
