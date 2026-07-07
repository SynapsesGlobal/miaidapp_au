import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';

class Checkout extends StatefulWidget {
  const Checkout({super.key});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  String selectedPaymentMethod = 'Credit card';
  bool subscribeEmails = false;
  String selectedShippingAddressId = '1';
  String selectedBillingAddressId = '1';

  final List<Map<String, String>> addresses = [
    {'id': '1', 'name': 'John Doe', 'address': '123 Main Street, Apt 4B New York, NY 1001, United States'},
    {'id': '2', 'name': 'John Doe', 'address': '123 Main Street, Apt 4B New York, NY 1001, United States'},
    {'id': '3', 'name': 'John Doe', 'address': '123 Main Street, Apt 4B New York, NY 1001, United States'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          '订单结算',
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildProductSummary(),
            SizedBox(height: 20),
            _buildNewsletter(),

            SizedBox(height: 5),
            _buildSectionTitle('Shipping Address'),
            _buildShippingAddress(),
            Divider(color: Colors.grey[100],),

            _buildSectionTitle('Billing Address'),
            _buildBillingAddress(),
            Divider(color: Colors.grey[100],),

            _buildSectionTitle('Payment Method'),
            _buildPaymentMethod('Paypal', Icons.paypal),
            _buildPaymentMethod('Apple pay', Icons.apple),
            _buildPaymentMethod('Credit card', Icons.credit_card),
            SizedBox(height: 10,),
            _buildCreditCard(),

            Divider(color: Colors.grey[100],),
            _buildSubtotal(),
            Divider(color: Colors.grey[100],),
            _buildTotal()
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        margin: EdgeInsets.only(bottom: 20),
        child: MaterialButton(
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          onPressed: () {

          },
          color: AppColors.k0cbcc5,
          child: Text('Submit order', style: GoogleFonts.rubik(
              color: Colors.white
          )),
        ),
      ),
    );
  }

  Widget _buildShippingAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: List.generate(addresses.length, (index) => GestureDetector(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selectedShippingAddressId == addresses[index]['id']! ? AppColors.k0cbcc5 : Color(0xFFF9FAFB))
            ),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(addresses[index]['name']!, style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w600
                  ),),
                  InkWell(
                    child: Text('Edit', style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: AppColors.k0cbcc5,
                        fontWeight: FontWeight.normal
                    ),),
                    onTap: (){},
                  )
                ],
              ),
              subtitle: Text(addresses[index]['address']!, style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.normal
              )),
            ),
          ),
          onTap: ()=> setState(() => selectedShippingAddressId = addresses[index]['id']!),
        ))),
        Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
          Icon(Icons.add_circle, color: AppColors.k0cbcc5,),
          SizedBox(width: 5,),
          InkWell(
            child: Text('Add new addresses', style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k0cbcc5,
                fontWeight: FontWeight.normal
            )),
            onTap: (){},
          )
        ],),)
      ],
    );
  }

  Widget _buildBillingAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: List.generate(addresses.length, (index) => GestureDetector(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selectedBillingAddressId == addresses[index]['id']! ? AppColors.k0cbcc5 : Color(0xFFF9FAFB))
            ),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(addresses[index]['name']!, style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.w600
                  ),),
                  InkWell(
                    child: Text('Edit', style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: AppColors.k0cbcc5,
                        fontWeight: FontWeight.normal
                    ),),
                    onTap: (){},
                  )
                ],
              ),
              subtitle: Text(addresses[index]['address']!, style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.normal
              )),
            ),
          ),
          onTap: ()=> setState(() => selectedBillingAddressId = addresses[index]['id']!),
        ))),
        Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
          Icon(Icons.add_circle, color: AppColors.k0cbcc5,),
          SizedBox(width: 5,),
          InkWell(
            child: Text('Add new addresses', style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k0cbcc5,
                fontWeight: FontWeight.normal
            )),
            onTap: (){},
          )
        ],),)
      ],
    );
  }

  Widget _buildPaymentMethod(String title, IconData icon) {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: InkWell(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: AppColors.kffffff,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(width: 1, color: Colors.black12)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(icon),
              SizedBox(width: 6,),
              Text(title, style: GoogleFonts.rubik(
                  fontWeight: FontWeight.normal,
                  fontSize: 14
              )),
            ],),
            SizedBox(
              height: 20,
              child: Radio(
                  value: title,
                  activeColor: AppColors.k0cbcc5,
                  groupValue: selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() => selectedPaymentMethod = value.toString());
                  }
              ),
            )
          ],
        ),
      ),
      onTap: (){
        setState(() => selectedPaymentMethod = title.toString());
      },
    ),);
  }

  Widget _buildProductSummary() {
    return Padding(padding: EdgeInsets.all(16), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/products/prod5.png', width: 100, fit: BoxFit.cover),
        SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anti-aging Therapy Session', style: GoogleFonts.rubik(
              fontWeight: FontWeight.bold,
            )),
            Text(
                'Comprehensive medical insurance package designed to provide extensive coverage for various medical and aesthetic procedures.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  color: Colors.grey,
                )
            ),
            Text('\$799', style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.k0cbcc5
            ),),
            Text('Quantity: 1', style: GoogleFonts.rubik(
                color: Colors.grey
            ),),
          ],
        ),),
      ],
    ),);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text(title, style: GoogleFonts.rubik(
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),),);
  }

  Widget _buildCreditCard() {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Visibility(
      visible: selectedPaymentMethod == 'Credit card',
      child: Column(children: [
        CupertinoTextField(
          placeholder: 'Card number',
          placeholderStyle: TextStyle(
              fontWeight: FontWeight.w400,
              color: CupertinoColors.placeholderText,
              fontSize: 14
          ),
          padding: EdgeInsets.all(12),
        ),
        SizedBox(height: 10,),
        Row(children: [
          Expanded(child: CupertinoTextField(
            placeholder: 'Expire date',
            placeholderStyle: TextStyle(
                fontWeight: FontWeight.w400,
                color: CupertinoColors.placeholderText,
                fontSize: 14
            ),
            padding: EdgeInsets.all(12),
          ),),
          SizedBox(width: 16),
          Expanded(child: CupertinoTextField(
            placeholder: 'CVV',
            placeholderStyle: TextStyle(
                fontWeight: FontWeight.w400,
                color: CupertinoColors.placeholderText,
                fontSize: 14
            ),
            padding: EdgeInsets.all(12),
          ),),
        ],),
        SizedBox(height: 10,),
        CupertinoTextField(
          placeholder: 'Card holder name',
          placeholderStyle: TextStyle(
              fontWeight: FontWeight.w400,
              color: CupertinoColors.placeholderText,
              fontSize: 14
          ),
          padding: EdgeInsets.all(12),
        ),
      ],),
    ),);
  }

  Widget _buildNewsletter() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Color(0xFFF9FAFB),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              activeColor: AppColors.k0cbcc5,
              checkColor: Colors.white,
              value: subscribeEmails,
              onChanged: (value) {
                setState(() => subscribeEmails = value!);
              },
            ),
          ),
          Expanded(child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Subscribe to newsletter', style: GoogleFonts.rubik(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),),
              Text('You will receive personalized emails from MiAid about products and services.', style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.grey
              ))
            ],),
          )),
        ],
      ),
    );
  }

  Widget _buildSubtotal() {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Subtotal'),
          Text('\$300')
        ],
      ),
      SizedBox(height: 5,),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Shipping'),
          Text('\$0.00')
        ],
      )
    ],),);
  }

  Widget _buildTotal() {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Total', style: GoogleFonts.rubik(
            fontWeight: FontWeight.bold,
            fontSize: 14
        )),
        Text('\$300', style: GoogleFonts.rubik(
            fontWeight: FontWeight.bold,
            fontSize: 14
        ))
      ],
    ),);
  }
}
