public class OrderLineItemTriggerHandler {
    
    public static boolean firstRoute = true;
    public static boolean fieldValuesDiffer = false;
    public static void afterInsert(List<Order_Line_Item__c> orderLIs) {
        
        List<Id> sourceOrders = new List<Id>();
        List<String> AWSIDs = new List<String>();
        Map<String, List<Order_Line_Item__c>> ordersToLineItems = new Map<String, List<Order_Line_Item__c>>();

        /*
        cycle through trigger List. populate map of orders to
        order line items list. populate source orders list.
        */
        for(Order_Line_Item__c orderItem : orderLIs){
            System.debug('ORDER LINE ITEM: ' + orderItem.Id);
            System.debug('SOURCE ORDER: ' + orderItem.Order__c);
            System.debug('SOURCE ORDER EXTERNAL ID: ' + orderItem.Parent_Order_External_Id__c);
            sourceOrders.add(orderItem.Order__c);
            if(!ordersToLineItems.containsKey(orderItem.Parent_Order_External_Id__c)){
                ordersToLineItems.put(orderItem.Parent_Order_External_Id__c, new List<Order_Line_Item__c>{orderItem});
            } else{
                ordersToLineItems.get(orderItem.Parent_Order_External_Id__c).add(orderItem);
            }
        }

        /*
        uses source orders to get external Ids for orders - to be
        removed following implementation of Parent_Order_External_Id__c
        custom field for order line item object.
        */
        List<Order__c> targetOrders = [SELECT Id, Account__c, Account__r.OwnerId, Ord_Id__c, Order_Sub_Total__c FROM Order__c WHERE Id IN: sourceOrders];
        for(Order__c order : targetOrders){
            System.debug('target orders AWSIDS: ' + order.Id);
            AWSIDs.add(order.Ord_Id__c);
        }
        System.debug('AWSIDs: ' + AWSIDs);
        List<Opportunity> targetOpps = [SELECT Id, AccountId, AWS_Order_ID__c, Amount FROM Opportunity WHERE AWS_Order_ID__c IN: AWSIDs];
        Map<String, List<OpportunityLineItem>> oppsToProducts = new Map<String, List<OpportunityLineItem>>();
          for(Opportunity opp : targetOpps){
            System.debug('target Opp: ' + opp.Id);
                for(OpportunityLineItem oppProduct : [SELECT Id, OpportunityId, Name, Opportunity.AWS_Order_ID__c, Product2Id, Quantity, ProductCode, UnitPrice, ListPrice, TotalPrice FROM OpportunityLineItem WHERE OpportunityId =: opp.Id ]){
                System.debug('products in current opp: ' + oppProduct.Id + ' product name: ' + oppProduct.Name);
                    if(!oppsToProducts.containsKey(opp.AWS_Order_ID__c)){
                        oppsToProducts.put(opp.AWS_Order_ID__c, new List<OpportunityLineItem>{oppProduct});
                    } else {
                        oppsToProducts.get(opp.AWS_Order_ID__c).add(oppProduct);
                    }
                }
            }

        If(!targetOrders.isEmpty() && !targetOpps.isEmpty() && !oppsToProducts.isEmpty()){

            List<OpportunityLineItem> productUpdateList = new List<OpportunityLineItem>();
            System.debug('oppsToProducts: (outer loop) ' + oppsToProducts.keySet());
            for(String ExternalId : oppsToProducts.keySet()){
                Integer iterator = 0;
                System.debug('current opp aws Id: ' + ExternalId);
                List<OpportunityLineItem> oppLineItems = oppsToProducts.get(ExternalId);
                List<Order_Line_Item__c> ordLineItems = ordersToLineItems.get(ExternalId);
                if(!oppLineItems.isEmpty() && !ordLineItems.isEmpty()){
                    
                    for(Order_Line_Item__c oli : ordLineItems){
                        do{
                        System.debug('oppItems List size: ' + oppLineItems.size());
                        System.debug('orderItems List size: ' + ordLineItems.size());
                            System.debug('oli ProductId:' + oli.Product_Id__c);
                            System.debug('opp item product code: ' + oppLineItems[iterator].ProductCode);
                            if(oli.Product_Id__c.equals(oppLineItems[iterator].ProductCode)){
                                Decimal unitPriceHolder = oppLineItems.get(iterator).UnitPrice;
                                oppLineItems.get(iterator).Quantity = oli.Order_Item_Quantity__c;
                                oppLineItems.get(iterator).UnitPrice = oppLineItems.get(iterator).ListPrice;
                                //oppLineItems.get(iterator).TotalPrice = oli.Order_Item_Quantity__c * oppLineItems.get(iterator).ListPrice;
                                fieldValuesDiffer = true;
                                productUpdateList.add(oppLineItems.get(iterator));
                                iterator++;
                            } else{
                                iterator++;
                            }
                        }while(iterator < oppLineItems.size());
                    }                 
                }
            }

            update productUpdateList;
        }
    }

    
}