package com.example.audit;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public class OrderProcessingService {

    private final List<Order> orders = new ArrayList<>();

    public static void main(String[] args) {
        OrderProcessingService service = new OrderProcessingService();

        service.createOrder("Laptop", 2, 75000);
        service.createOrder("Keyboard", 1, 2500);
        service.createOrder("Mouse", 3, 1200);

        service.printAllOrders();

        double total = service.calculateTotalRevenue();
        System.out.println("Total Revenue: " + total);

        service.processOrders();
    }

    public void createOrder(String itemName, int quantity, double price) {
        Order order = new Order();
        order.setId(UUID.randomUUID().toString());
        order.setItemName(itemName);
        order.setQuantity(quantity);
        order.setPrice(price);
        order.setCreatedTime(LocalDateTime.now());

        orders.add(order);

        System.out.println("Order created for item: " + itemName);
    }

    public void processOrders() {
        System.out.println("Processing orders...");

        for (Order order : orders) {

            if (validateOrder(order)) {

                double totalPrice = calculateOrderPrice(order);

                System.out.println(
                    "Processed Order: "
                        + order.getItemName()
                        + " | Quantity: "
                        + order.getQuantity()
                        + " | Total Price: "
                        + totalPrice
                );

                generateInvoice(order);

            } else {
                System.out.println(
                    "Invalid order found: "
                        + order.getId()
                );
            }
        }
    }

    public boolean validateOrder(Order order) {

        if (order == null) {
            return false;
        }

        if (order.getItemName() == null || order.getItemName().isEmpty()) {
            return false;
        }

        if (order.getQuantity() <= 0) {
            return false;
        }

        if (order.getPrice() <= 0) {
            return false;
        }

        return true;
    }

    public double calculateOrderPrice(Order order) {
        return order.getQuantity() * order.getPrice();
    }

    public double calculateTotalRevenue() {

        double total = 0;

        for (Order order : orders) {
            total += calculateOrderPrice(order);
        }

        return total;
    }

    public void printAllOrders() {

        System.out.println("Printing all orders...");

        for (Order order : orders) {

            System.out.println(
                "Order ID: " + order.getId()
                    + " | Item: " + order.getItemName()
                    + " | Quantity: " + order.getQuantity()
                    + " | Price: " + order.getPrice()
                    + " | Created: " + order.getCreatedTime()
            );
        }
    }

    public void generateInvoice(Order order) {

        System.out.println("Generating invoice...");

        String invoice = ""
            + "--------------------------\n"
            + "INVOICE\n"
            + "--------------------------\n"
            + "Item: " + order.getItemName() + "\n"
            + "Quantity: " + order.getQuantity() + "\n"
            + "Unit Price: " + order.getPrice() + "\n"
            + "Total: " + calculateOrderPrice(order) + "\n"
            + "Generated Time: " + LocalDateTime.now() + "\n"
            + "--------------------------";

        System.out.println(invoice);
    }

    static class Order {

        private String id;
        private String itemName;
        private int quantity;
        private double price;
        private LocalDateTime createdTime;

        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public String getItemName() {
            return itemName;
        }

        public void setItemName(String itemName) {
            this.itemName = itemName;
        }

        public int getQuantity() {
            return quantity;
        }

        public void setQuantity(int quantity) {
            this.quantity = quantity;
        }

        public double getPrice() {
            return price;
        }

        public void setPrice(double price) {
            this.price = price;
        }

        public LocalDateTime getCreatedTime() {
            return createdTime;
        }

        public void setCreatedTime(LocalDateTime createdTime) {
            this.createdTime = createdTime;
        }
    }
}
