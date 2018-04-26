angular.module 'mnoEnterpriseAngular'
  .controller('ProvisioningOrderCtrl', ($scope, $q, $state, $stateParams, MnoeOrganizations, MnoeMarketplace, MnoeProvisioning, MnoeConfig, ProvisioningHelper) ->

    vm = this
    vm.isLoading = true
    vm.product = null

    orgPromise = MnoeOrganizations.get()
    prodsPromise = MnoeMarketplace.getProducts()
    initPromise = MnoeProvisioning.initSubscription({productId: $stateParams.productId, subscriptionId: $stateParams.subscriptionId})

    # Return true if the plan has a dollar value
    vm.pricedPlan = ProvisioningHelper.pricedPlan

    $q.all({organization: orgPromise, products: prodsPromise, subscription: initPromise}).then(
      (response) ->
        vm.orgCurrency = response.organization.organization?.billing_currency || MnoeConfig.marketplaceCurrency()
        vm.subscription = response.subscription

        # When in edit mode, we will be getting the product ID from the subscription, otherwise from the url.
        productId = vm.subscription.product?.id || $stateParams.productId
        MnoeMarketplace.getProduct(productId, { editAction: $stateParams.editAction }).then(
          (response) ->
            vm.subscription.product = response

            # Skip pricing selection when applicable
            vm.next(vm.subscription) if vm.skipPriceSelection(vm.subscription.product)

            # Filters the pricing plans not containing current currency
            vm.subscription.product.pricing_plans = _.filter(vm.subscription.product.pricing_plans,
              (pp) -> !vm.pricedPlan(pp) || _.some(pp.prices, (p) -> p.currency == vm.orgCurrency)
            )

            vm.selectPlan = (pricingPlan)->
              vm.subscription.product_pricing = pricingPlan
              vm.subscription.max_licenses ||= 1 if vm.subscription.product_pricing.license_based


            MnoeProvisioning.setSubscription(vm.subscription)
        )
    ).finally(-> vm.isLoading = false)

    vm.next = (subscription) ->
      MnoeProvisioning.setSubscription(subscription)

      params = {
        productId: $stateParams.productId,
        subscriptionId: $stateParams.subscriptionId,
        editAction: $stateParams.editAction
      }

      if vm.subscription.product.custom_schema?
        $state.go('home.provisioning.additional_details', params)
      else
        $state.go('home.provisioning.confirm', params)

    vm.pricedPlan = ProvisioningHelper.pricedPlan

    # Delete the cached subscription when we are leaving the subscription workflow.
    $scope.$on('$stateChangeStart', (event, toState) ->
      switch toState.name
        when "home.provisioning.confirm", "home.provisioning.order_summary", "home.provisioning.additional_details"
          null
        else
          MnoeProvisioning.setSubscription({})
    )

    vm.skipPriceSelection = (product) ->
      product.product_type == 'application' && (!product.single_billing_enabled || !product.billed_locally)

    vm.subscriptionPlanText = () ->
      switch $stateParams.editAction
        when 'NEW'
          'mno_enterprise.templates.dashboard.provisioning.order.new_title'
        when 'CHANGE'
          'mno_enterprise.templates.dashboard.provisioning.order.change_title'

    return
  )
